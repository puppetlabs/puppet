require 'puppet/util/network_device/cisco'
require 'puppet/util/network_device/ipcalc'

# this manages setting properties to an interface in a cisco switch or router
class Puppet::Util::NetworkDevice::Cisco::Interface

  include Puppet::Util::NetworkDevice::IPCalc
  extend Puppet::Util::NetworkDevice::IPCalc

  attr_reader :transport, :name

  def initialize(name, transport)
    @name = name
    @transport = transport
  end

  COMMANDS = {
    # property     => order, ios command/block/array
    :description   => [1, "description %s"],
    :speed         => [2, "speed %s"],
    :duplex        => [3, "duplex %s"],
    :native_vlan   => [4, "switchport access vlan %s"],
    :encapsulation => [5, "switchport trunk encapsulation %s"],
    :mode          => [6, "switchport mode %s"],
    :allowed_trunk_vlans => [7, "switchport trunk allowed vlan %s"],
    :etherchannel  => [8, ["channel-group %s", "port group %s"]],
    :ipaddress     => [9,
      lambda do |prefix,ip,option|
        ip.ipv6? ? "ipv6 address #{ip.to_s}/#{prefix} #{option}" :
                   "ip address #{ip.to_s} #{netmask(Socket::AF_INET,prefix)}"
      end],
      :ensure        => [10, lambda { |value| value == :present ? "no shutdown" : "shutdown" } ]
  }

  def update(is={}, should={})
    Puppet.debug("Updating interface #{name}")
    command("conf t")
    command("interface #{name}")

    # apply changes in a defined orders for cisco IOS devices
    [is.keys, should.keys].flatten.uniq.sort {|a,b| COMMANDS[a][0] <=> COMMANDS[b][0] }.each do |property|
      # They're equal, so do nothing.
      next if is[property] == should[property]

      # We're deleting it
      if should[property] == :absent or should[property].nil?
        execute(property, is[property], "no ")
        next
      end

      # We're replacing an existing value or creating a new one
      execute(property, should[property])
    end

    command("exit")
    command("exit")
  end

  def execute(property, value, prefix='')
    case COMMANDS[property][1]
    when Array
      COMMANDS[property][1].each do |command|
        transport.command(prefix + command % value) do |out|
          break unless out =~ /^%/
        end
      end
    when String
      command(prefix + COMMANDS[property][1] % value)
    when Proc
      value = [value] unless value.is_a?(Array)
      value.each do |value|
        command(prefix + COMMANDS[property][1].call(*value))
      end
    end
  end

  def command(command)
    transport.command(command) do |out|
      Puppet.err "Error while executing #{command}, device returned #{out}" if out =~ /^%/mo
    end
  end
end