require 'puppet/util/network_device/cisco/device'
require 'puppet/provider/network_device'

Puppet::Type.type(:vlan).provide :cisco, :parent => Puppet::Provider::NetworkDevice do

  desc "Cisco switch/router provider for vlans."

  mk_resource_methods

  def self.lookup(url, id)
    vlans = {}
    device = Puppet::Util::NetworkDevice::Cisco::Device.new(url)
    device.command do |d|
      vlans = d.parse_vlans || {}
    end
    vlans[id]
  end

  def initialize(*args)
    super
  end

  # Clear out the cached values.
  def flush
    device.command do |device|
      device.update_vlan(resource[:name], former_properties, properties)
    end
    super
  end

  def device
    @device ||= Puppet::Util::NetworkDevice::Cisco::Device.new(resource[:device_url])
  end
end
