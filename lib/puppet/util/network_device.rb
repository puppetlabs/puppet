class Puppet::Util::NetworkDevice
  class << self
    attr_reader :current
  end

  def self.init(device)
    require "puppet/util/network_device/#{device.provider}/device"
    @current = Puppet::Util::NetworkDevice.const_get(device.provider.capitalize).const_get(:Device).new(device.url, device.options)
  rescue => detail
    raise detail, _("Can't load %{provider} for %{device}: %{detail}") % { provider: device.provider, device: device.name, detail: detail }, detail.backtrace
  end

  # Should only be used in tests
  def self.teardown
    @current = nil
  end
end
