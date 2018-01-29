require 'puppet'
require 'puppet/util'
require 'puppet/util/network_device/base'
require 'puppet/util/network_device/ipcalc'
require 'puppet/util/network_device/cisco/interface'
require 'puppet/util/network_device/cisco/facts'
require 'ipaddr'

class Puppet::Util::NetworkDevice::Cisco::Device < Puppet::Util::NetworkDevice::Base

  include Puppet::Util::NetworkDevice::IPCalc

  attr_accessor :enable_password

  def initialize(url, options = {})
    super(url, options)
    @enable_password = options[:enable_password] || parse_enable(@url.query)
    transport.default_prompt = /[#>]\s?\z/n
  end

  def parse_enable(query)
    if query
      params = CGI.parse(query)
      params['enable'].first unless params['enable'].empty?
    end
  end

  def connect
    transport.connect
    login
    transport.command("terminal length 0") do |out|
      enable if out =~ />\s?\z/n
    end
    find_capabilities
  end

  def disconnect
    transport.close
  end

  def command(cmd = nil)
    connect
    out = execute(cmd) if cmd
    yield self if block_given?
    disconnect
    out
  end

  def execute(cmd)
    transport.command(cmd) do |out|
      if out =~ /^%/mo or out =~ /^Command rejected:/mo
        # strip off the command just sent
        error = out.sub(cmd,'')
        Puppet.err _("Error while executing '%{cmd}', device returned: %{error}") % { cmd: cmd, error: error }
      end
    end
  end

  def login
    return if transport.handles_login?
    if @url.user != ''
      transport.command(@url.user, :prompt => /^Password:/)
    else
      transport.expect(/^Password:/)
    end
    transport.command(@url.password)
  end

  def enable
    raise _("Can't issue \"enable\" to enter privileged, no enable password set") unless enable_password
    transport.command("enable", :prompt => /^Password:/)
    transport.command(enable_password)
  end

  def support_vlan_brief?
    !! @support_vlan_brief
  end

  def find_capabilities
    out = execute("sh vlan brief")
    lines = out.split("\n")
    lines.shift; lines.pop

    @support_vlan_brief = ! (lines.first =~ /^%/)
  end

  IF = {
    :FastEthernet => %w{FastEthernet FastEth Fast FE Fa F},
    :GigabitEthernet => %w{GigabitEthernet GigEthernet GigEth GE Gi G},
    :TenGigabitEthernet => %w{TenGigabitEthernet TE Te},
    :Ethernet => %w{Ethernet Eth E},
    :Serial => %w{Serial Se S},
    :PortChannel => %w{PortChannel Port-Channel Po},
    :POS => %w{POS P},
    :VLAN => %w{VLAN VL V},
    :Loopback => %w{Loopback Loop Lo},
    :ATM => %w{ATM AT A},
    :Dialer => %w{Dialer Dial Di D},
    :VirtualAccess => %w{Virtual-Access Virtual-A Virtual Virt}
  }

  def canonicalize_ifname(interface)
    IF.each do |k,ifnames|
      if found = ifnames.find { |ifname| interface =~ /^#{ifname}\s*\d/i }
        found = /^#{found}(.+)\Z/i.match(interface)
        return "#{k.to_s}#{found[1]}".gsub(/\s+/,'')
      end
    end
    interface
  end

  def facts
    @facts ||= Puppet::Util::NetworkDevice::Cisco::Facts.new(transport)
    facts = {}
    command do |ng|
      facts = @facts.retrieve
    end
    facts
  end

  def interface(name)
    ifname = canonicalize_ifname(name)
    interface = parse_interface(ifname)
    return { :ensure => :absent } if interface.empty?
    interface.merge!(parse_trunking(ifname))
    interface.merge!(parse_interface_config(ifname))
  end

  def new_interface(name)
    Puppet::Util::NetworkDevice::Cisco::Interface.new(canonicalize_ifname(name), transport)
  end

  def parse_interface(name)
    resource = {}
    out = execute("sh interface #{name}")
    lines = out.split("\n")
    lines.shift; lines.pop
    lines.each do |l|
      if l =~ /#{name} is (.+), line protocol is /
        resource[:ensure] = ($1 == 'up' ? :present : :absent);
      end
      if l =~ /Auto Speed \(.+\),/ or l =~ /Auto Speed ,/ or l =~ /Auto-speed/
        resource[:speed] = :auto
      end
      if l =~ /, (.+)Mb\/s/
        resource[:speed] = $1
      end
      if l =~ /\s+Auto-duplex \((.{4})\),/
        resource[:duplex] = :auto
      end
      if l =~ /\s+(.+)-duplex/
        resource[:duplex] = $1 == "Auto" ? :auto : $1.downcase.to_sym
      end
      if l =~ /Description: (.+)/
        resource[:description] = $1
      end
    end
    resource
  end

  def parse_interface_config(name)
    resource = Hash.new { |hash, key| hash[key] = Array.new ; }
    out = execute("sh running-config interface #{name} | begin interface")
    lines = out.split("\n")
    lines.shift; lines.pop
    lines.each do |l|
      if l =~ /ip address (#{IP}) (#{IP})\s+secondary\s*$/
        resource[:ipaddress] << [prefix_length(IPAddr.new($2)), IPAddr.new($1), 'secondary']
      end
      if l =~ /ip address (#{IP}) (#{IP})\s*$/
        resource[:ipaddress] << [prefix_length(IPAddr.new($2)), IPAddr.new($1), nil]
      end
      if l =~ /ipv6 address (#{IP})\/(\d+) (eui-64|link-local)/
        resource[:ipaddress] << [$2.to_i, IPAddr.new($1), $3]
      end
      if l =~ /channel-group\s+(\d+)/
        resource[:etherchannel] = $1
      end
    end
    resource
  end

  def parse_vlans
    vlans = {}
    out = execute(support_vlan_brief? ? "sh vlan brief" : "sh vlan-switch brief")
    lines = out.split("\n")
    lines.shift; lines.shift; lines.shift; lines.pop
    vlan = nil
    lines.each do |l|
      case l
            # vlan    name    status
      when /^(\d+)\s+(\w+)\s+(\w+)\s+([a-zA-Z0-9,\/. ]+)\s*$/
        vlan = { :name => $1, :description => $2, :status => $3, :interfaces => [] }
        if $4.strip.length > 0
          vlan[:interfaces] = $4.strip.split(/\s*,\s*/).map{ |ifn| canonicalize_ifname(ifn) }
        end
        vlans[vlan[:name]] = vlan
      when /^\s+([a-zA-Z0-9,\/. ]+)\s*$/
        raise _("invalid sh vlan summary output") unless vlan
        if $1.strip.length > 0
          vlan[:interfaces] += $1.strip.split(/\s*,\s*/).map{ |ifn| canonicalize_ifname(ifn) }
        end
      else
      end
    end
    vlans
  end

  def update_vlan(id, is = {}, should = {})
    if should[:ensure] == :absent
      Puppet.info _("Removing %{id} from device vlan") % { id: id }
      execute("conf t")
      execute("no vlan #{id}")
      execute("exit")
      return
    end

    # Cisco VLANs are supposed to be alphanumeric only
    if should[:description] =~ /[^\w]/
      Puppet.err _("Invalid VLAN name '%{name}' for Cisco device.\nVLAN name must be alphanumeric, no spaces or special characters.") % { name: should[:description] }
      return
    end
    
    # We're creating or updating an entry
    execute("conf t")
    execute("vlan #{id}")
    [is.keys, should.keys].flatten.uniq.each do |property|
      Puppet.debug("trying property: #{property}: #{should[property]}")
      next if property != :description
      execute("name #{should[property]}")
    end
    execute("exit")
    execute("exit")
  end

  def parse_trunking(interface)
    trunking = {}
    out = execute("sh interface #{interface} switchport")
    lines = out.split("\n")
    lines.shift; lines.pop
    lines.each do |l|
      case l
      when /^Administrative mode:\s+(.*)$/i
        case $1
        when "trunk"
          trunking[:mode] = :trunk
        when "static access"
          trunking[:mode] = :access
        when "dynamic auto"
          trunking[:mode] = 'dynamic auto'
        when "dynamic desirable"
          trunking[:mode] = 'dynamic desirable'
        else
          raise _("Unknown switchport mode: %{mode} for %{interface}") % { mode: $1, interface: interface }
        end
      when /^Administrative Trunking Encapsulation:\s+(.*)$/
        case $1
        when "dot1q","isl"
          trunking[:encapsulation] = $1.to_sym if trunking[:mode] != :access
        when "negotiate"
          trunking[:encapsulation] = :negotiate
        else
          raise _("Unknown switchport encapsulation: %{value} for %{interface}") % { value: $1, interface: interface }
        end
      when /^Access Mode VLAN:\s+(.*) \((.*)\)$/
        trunking[:access_vlan] = $1 if $2 != '(Inactive)'
      when /^Trunking Native Mode VLAN:\s+(.*) \(.*\)$/
        trunking[:native_vlan] = $1
      when /^Trunking VLANs Enabled:\s+(.*)$/
        next if trunking[:mode] == :access
        vlans = $1
        trunking[:allowed_trunk_vlans] = case vlans
        when /all/i
          :all
        when /none/i
          :none
        else
          vlans
        end
      end
    end
    trunking
  end

end
