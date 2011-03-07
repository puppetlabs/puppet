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
end
