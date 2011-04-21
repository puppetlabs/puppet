require 'puppet/util/network_device/cisco/device'
require 'puppet/provider/network_device'

# This is the base class of all prefetched cisco device providers
class Puppet::Provider::Cisco < Puppet::Provider::NetworkDevice
  def self.device(url)
    Puppet::Util::NetworkDevice::Cisco::Device.new(url)
  end
end
