require 'puppet/indirector/memory'

class Puppet::IndirectorTesting::Memory < Puppet::Indirector::Memory
  def supports_remote_requests?
    true
  end
end
