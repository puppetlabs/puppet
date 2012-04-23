
require 'puppet/util/network_device'
require 'puppet/util/network_device/transport'

class Puppet::Util::NetworkDevice::Transport::Base
  attr_accessor :user, :password, :host, :port
  attr_accessor :default_prompt, :timeout

  def initialize
    @timeout = 10
  end

  def send(cmd)
  end

  def expect(prompt)
  end

  def command(cmd, options = {})
    send(cmd)
    expect(options[:prompt] || default_prompt) do |output|
      yield output if block_given?
    end
  end

end
