require 'puppet/util/network_device/cisco/device'
require 'puppet/provider/network_device'

Puppet::Type.type(:interface).provide :cisco, :parent => Puppet::Provider::NetworkDevice do

  desc "Cisco switch/router provider for interface."

  mk_resource_methods

  def self.lookup(url, name)
    interface = nil
    network_gear = Puppet::Util::NetworkDevice::Cisco::Device.new(url)
    network_gear.command do |ng|
      interface = network_gear.interface(name)
    end
    interface
  end

  def initialize(*args)
    super
  end

  def flush
    device.command do |device|
      device.new_interface(name).update(former_properties, properties)
    end
    super
  end

  def device
    @device ||= Puppet::Util::NetworkDevice::Cisco::Device.new(resource[:device_url])
  end
end
