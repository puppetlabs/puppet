require 'puppet/rails/inventory_host'
require 'puppet/rails/inventory_fact'
require 'puppet/indirector/active_record'

class Puppet::Node::Facts::InventoryActiveRecord < Puppet::Indirector::ActiveRecord
  def find(request)
    host = Puppet::Rails::InventoryHost.find_by_name(request.key)
    return nil unless host
    facts = Puppet::Node::Facts.new(host.name, host.facts_to_hash)
    facts.timestamp = host.timestamp
    facts.values.each do |key,value|
      facts.values[key] = value.first if value.is_a?(Array) && value.length == 1
    end
    facts
  end

  def save(request)
    facts = request.instance
    host = Puppet::Rails::InventoryHost.find_by_name(request.key) || Puppet::Rails::InventoryHost.create(:name => request.key, :timestamp => facts.timestamp)
    host.timestamp = facts.timestamp

    ActiveRecord::Base.transaction do
      Puppet::Rails::InventoryFact.delete_all(:inventory_host_id => host.id)
      # We don't want to save internal values as facts, because those are
      # metadata that belong on the host
      facts.values.each do |name,value|
        next if name.to_s =~ /^_/
        host.facts.build(:name => name, :value => value)
      end
      host.save
    end
  end

  def search(request)
    return [] unless request.options
    fact_names = []
    filters = Hash.new {|h,k| h[k] = []}
    request.options.each do |key,value|
      type, name, operator = key.to_s.split(".")
      operator ||= "eq"
      filters[operator] << [name,value]
    end


    host_sets = []
    filters['eq'].each do |name,value|
      host_sets << Puppet::Rails::InventoryHost.has_fact_with_value(name,value).map {|host| host.name}
    end
    filters['ne'].each do |name,value|
      host_sets << Puppet::Rails::InventoryHost.has_fact_without_value(name,value).map {|host| host.name}
    end
    {
      'gt' => '>',
      'lt' => '<',
      'ge' => '>=',
      'le' => '<='
    }.each do |operator_name,operator|
      filters[operator_name].each do |name,value|
        hosts_with_fact = Puppet::Rails::InventoryHost.has_fact(name)
        host_sets << hosts_with_fact.select {|h| h.value_for(name).to_f.send(operator, value.to_f)}.map {|host| host.name}
      end
    end

    # to_a because [].inject == nil
    host_sets.inject {|hosts,this_set| hosts & this_set}.to_a
  end
end
