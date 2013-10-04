require 'puppet/node/facts'
require 'puppet/indirector/rest'

class Puppet::Node::Facts::InventoryService < Puppet::Indirector::REST
  desc "Find and save facts about nodes using a remote inventory service."
  use_server_setting(:inventory_server)
  use_port_setting(:inventory_port)

  # We don't want failing to upload to the inventory service to cause any
  # failures, so we just suppress them and warn.
  def save(request)
    begin
      super
      true
    rescue => e
      Puppet.warning "Could not upload facts for #{request.key} to inventory service: #{e.to_s}"
      false
    end
  end
end
