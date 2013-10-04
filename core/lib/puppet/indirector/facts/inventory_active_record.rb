require 'puppet/rails'
require 'puppet/rails/inventory_node'
require 'puppet/rails/inventory_fact'
require 'puppet/indirector/active_record'
require 'puppet/util/retryaction'

class Puppet::Node::Facts::InventoryActiveRecord < Puppet::Indirector::ActiveRecord

  desc "Medium-performance fact storage suitable for the inventory service.
    Most users should use PuppetDB instead. Note: ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

  def initialize
    raise Puppet::Error, "ActiveRecords-based inventory is unsupported with Ruby 2 and Rails 3.0" if RUBY_VERSION[0] == '2'
    Puppet.deprecation_warning "ActiveRecord-based storeconfigs and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"
    super
  end

  def find(request)
    node = Puppet::Rails::InventoryNode.find_by_name(request.key)
    return nil unless node
    facts = Puppet::Node::Facts.new(node.name, node.facts_to_hash)
    facts.timestamp = node.timestamp
    facts
  end

  def save(request)
    Puppet::Util::RetryAction.retry_action :retries => 4, :retry_exceptions => {ActiveRecord::StatementInvalid => 'MySQL Error.  Retrying'} do
      facts = request.instance
      node = Puppet::Rails::InventoryNode.find_by_name(request.key) || Puppet::Rails::InventoryNode.create(:name => request.key, :timestamp => facts.timestamp)
      node.timestamp = facts.timestamp

      ActiveRecord::Base.transaction do
        Puppet::Rails::InventoryFact.delete_all(:node_id => node.id)
        # We don't want to save internal values as facts, because those are
        # metadata that belong on the node
        facts.values.each do |name,value|
          next if name.to_s =~ /^_/
          node.facts.build(:name => name, :value => value)
        end
        node.save
      end
    end
  end

  def search(request)
    return [] unless request.options
    matching_nodes = []
    fact_filters = Hash.new {|h,k| h[k] = []}
    meta_filters = Hash.new {|h,k| h[k] = []}
    request.options.each do |key,value|
      type, name, operator = key.to_s.split(".")
      operator ||= "eq"
      if type == "facts"
        fact_filters[operator] << [name,value]
      elsif type == "meta" and name == "timestamp"
        meta_filters[operator] << [name,value]
      end
    end

    matching_nodes = nodes_matching_fact_filters(fact_filters) + nodes_matching_meta_filters(meta_filters)

    # to_a because [].inject == nil
    matching_nodes.inject {|nodes,this_set| nodes & this_set}.to_a.sort
  end

  private

  def nodes_matching_fact_filters(fact_filters)
    node_sets = []
    fact_filters['eq'].each do |name,value|
      node_sets << Puppet::Rails::InventoryNode.has_fact_with_value(name,value).map {|node| node.name}
    end
    fact_filters['ne'].each do |name,value|
      node_sets << Puppet::Rails::InventoryNode.has_fact_without_value(name,value).map {|node| node.name}
    end
    {
      'gt' => '>',
      'lt' => '<',
      'ge' => '>=',
      'le' => '<='
    }.each do |operator_name,operator|
      fact_filters[operator_name].each do |name,value|
        facts = Puppet::Rails::InventoryFact.find_by_sql(["SELECT inventory_facts.value, inventory_nodes.name AS node_name
                                                           FROM inventory_facts INNER JOIN inventory_nodes
                                                           ON inventory_facts.node_id = inventory_nodes.id
                                                           WHERE inventory_facts.name = ?", name])
        node_sets << facts.select {|fact| fact.value.to_f.send(operator, value.to_f)}.map {|fact| fact.node_name}
      end
    end
    node_sets
  end

  def nodes_matching_meta_filters(meta_filters)
    node_sets = []
    {
      'eq' => '=',
      'ne' => '!=',
      'gt' => '>',
      'lt' => '<',
      'ge' => '>=',
      'le' => '<='
    }.each do |operator_name,operator|
      meta_filters[operator_name].each do |name,value|
        node_sets << Puppet::Rails::InventoryNode.find(:all, :select => "name", :conditions => ["timestamp #{operator} ?", value]).map {|node| node.name}
      end
    end
    node_sets
  end
end
