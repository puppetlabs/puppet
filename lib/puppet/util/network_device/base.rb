require 'puppet/util/autoload'
require 'uri'
require 'puppet/util/network_device/transport'
require 'puppet/util/network_device/transport/base'

class Puppet::Util::NetworkDevice::Base

  attr_accessor :url, :transport

  def initialize(url, options = {})
    @url = URI.parse(url)

    @autoloader = Puppet::Util::Autoload.new(self, "puppet/util/network_device/transport")

    if @autoloader.load(@url.scheme)
      @transport = Puppet::Util::NetworkDevice::Transport.const_get(@url.scheme.capitalize).new(options[:debug])
      @transport.host = @url.host
      @transport.port = @url.port || case @url.scheme ; when "ssh" ; 22 ; when "telnet" ; 23 ; end
      @transport.user = @url.user
      @transport.password = @url.password
    end
  end
end
