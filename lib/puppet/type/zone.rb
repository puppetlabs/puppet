require 'puppet/property/list'
Puppet::Type.newtype(:zone) do
  @doc = "Manages Solaris zones.

**Autorequires:** If Puppet is managing the directory specified as the root of
the zone's filesystem (with the `path` attribute), the zone resource will
autorequire that directory."

module Puppet::Zone
  class StateMachine
    # A silly little state machine.
    def initialize
      @state = {}
      @sequence = []
      @state_aliases = {}
      @default = nil
    end

    # The order of calling insert_state is important
    def insert_state(name, transitions)
      @sequence << name
      @state[name] = transitions
    end

    def alias_state(state, salias)
      @state_aliases[state] = salias
    end

    def name(n)
      @state_aliases[n.to_sym] || n.to_sym
    end

    def index(state)
      @sequence.index(name(state))
    end

    # return all states between fs and ss excluding fs
    def sequence(fs, ss)
      fi = index(fs)
      si= index(ss)
      (if fi > si
        then @sequence[si .. fi].map{|i| @state[i]}.reverse
        else @sequence[fi .. si].map{|i| @state[i]}
      end)[1..-1]
    end

    def cmp?(a,b)
      index(a) < index(b)
    end
  end
end

  making_surable do
    desc "The running state of the zone.  The valid states directly reflect
      the states that `zoneadm` provides.  The states are linear,
      in that a zone must be `configured`, then `installed`, and
      only then can be `running`.  Note also that `halt` is currently
      used to stop zones."

    def self.fsm
      return @fsm if @fsm
      @fsm = Puppet::Zone::StateMachine.new
    end

    def self.alias_state(values)
      values.each do |k,v|
        fsm.alias_state(k,v)
      end
    end

    def self.seqvalue(name, hash)
      fsm.insert_state(name, hash)
      self.newvalue name
    end

    # This is seq value because the order of declaration is important.
    # i.e we go linearly from :absent -> :configured -> :installed -> :running
    seqvalue :absent, :down => :destroy
    seqvalue :configured, :up => :configure, :down => :uninstall
    seqvalue :installed, :up => :install, :down => :stop
    seqvalue :running, :up => :start

    alias_state :incomplete => :installed, :ready => :installed, :shutting_down => :running

    defaultto :running

    def self.state_sequence(first, second)
      fsm.sequence(first, second)
    end

    # Why override it? because property/making_sure.rb has a default retrieve method
    # that knows only about :present and :absent. That method just calls
    # provider.exists? and returns :present if a result was returned.
    def retrieve
      provider.properties[:making_sure]
    end

    def provider_sync_send(method)
      warned = false
      while provider.processing?
        next if warned
        info "Waiting for zone to finish processing"
        warned = true
        sleep 1
      end
      provider.send(method)
      provider.flush()
    end

    def sync
      method = nil
      direction = up? ? :up : :down

      # We need to get the state we're currently in and just call
      # everything between it and us.
      self.class.state_sequence(self.retrieve, self.should).each do |state|
        method = state[direction]
        raise Puppet::DevError, "Cannot move #{direction} from #{st[:name]}" unless method
        provider_sync_send(method)
      end

      ("zone_#{self.should}").intern
    end

    # Are we moving up the property tree?
    def up?
      self.class.fsm.cmp?(self.retrieve, self.should)
    end

  end

  newparam(:name) do
    desc "The name of the zone."

    isnamevar
  end

  newparam(:id) do
    desc "The numerical ID of the zone.  This number is autogenerated
      and cannot be changed."
  end

  newparam(:clone) do
    desc "Instead of installing the zone, clone it from another zone.
      If the zone root resides on a zfs file system, a snapshot will be
      used to create the clone; if it resides on a ufs filesystem, a copy of the
      zone will be used. The zone from which you clone must not be running."
  end

  newproperty(:ip, :parent => Puppet::Property::List) do
    require 'ipaddr'

    desc "The IP address of the zone.  IP addresses **must** be specified
      with an interface, and may optionally be specified with a default router
      (sometimes called a defrouter). The interface, IP address, and default
      router should be separated by colons to form a complete IP address string.
      For example: `bge0:192.168.178.200` would be a valid IP address string
      without a default router, and `bge0:192.168.178.200:192.168.178.1` adds a
      default router to it.

      For zones with multiple interfaces, the value of this attribute should be
      an array of IP address strings (each of which must include an interface
      and may include a default router)."

    # The default action of list should is to lst.join(' '). By specifying
    # @should, we making_sure the should remains an array. If we override should, we
    # should also override insync?() -- property/list.rb
    def should
      @should
    end

    # overridden so that we match with self.should
    def insync?(is)
      return true unless is
      is = [] if is == :absent
      is.sort == self.should.sort
    end
  end

  newproperty(:iptype) do
    desc "The IP stack type of the zone."
    defaultto :shared
    newvalue :shared
    newvalue :exclusive
  end

  newproperty(:autoboot, :boolean => true) do
    desc "Whether the zone should automatically boot."
    defaultto true
    newvalues(:true, :false)
  end

  newproperty(:path) do
    desc "The root of the zone's filesystem.  Must be a fully qualified
      file name.  If you include `%s` in the path, then it will be
      replaced with the zone's name.  Currently, you cannot use
      Puppet to move a zone. Consequently this is a readonly property."

    validate do |value|
      raise ArgumentError, "The zone base must be fully qualified" unless value =~ /^\//
    end

    munge do |value|
      if value =~ /%s/
        value % @resource[:name]
      else
        value
      end
    end
  end

  newproperty(:pool) do
    desc "The resource pool for this zone."
  end

  newproperty(:shares) do
    desc "Number of FSS CPU shares allocated to the zone."
  end

  newproperty(:dataset, :parent => Puppet::Property::List ) do
    desc "The list of datasets delegated to the non-global zone from the
      global zone.  All datasets must be zfs filesystem names which are
      different from the mountpoint."

    def should
      @should
    end

    # overridden so that we match with self.should
    def insync?(is)
      return true unless is
      is = [] if is == :absent
      is.sort == self.should.sort
    end

    validate do |value|
      unless value !~ /^\//
        raise ArgumentError, "Datasets must be the name of a zfs filesystem"
      end
    end
  end

  newproperty(:inherit, :parent => Puppet::Property::List) do
    desc "The list of directories that the zone inherits from the global
      zone.  All directories must be fully qualified."

    def should
      @should
    end

    # overridden so that we match with self.should
    def insync?(is)
      return true unless is
      is = [] if is == :absent
      is.sort == self.should.sort
    end

    validate do |value|
      unless value =~ /^\//
        raise ArgumentError, "Inherited filesystems must be fully qualified"
      end
    end
  end

  # Specify the sysidcfg file.  This is pretty hackish, because it's
  # only used to boot the zone the very first time.
  newparam(:sysidcfg) do
    desc %{The text to go into the `sysidcfg` file when the zone is first
      booted.  The best way is to use a template:

          # $confdir/modules/site/templates/sysidcfg.erb
          system_locale=en_US
          timezone=GMT
          terminal=xterms
          security_policy=NONE
          root_password=<%= password %>
          timeserver=localhost
          name_service=DNS {domain_name=<%= domain %> name_server=<%= nameserver %>}
          network_interface=primary {hostname=<%= realhostname %>
            ip_address=<%= ip %>
            netmask=<%= netmask %>
            protocol_ipv6=no
            default_route=<%= defaultroute %>}
          nfs4_domain=dynamic

      And then call that:

          zone { myzone:
            ip           => "bge0:192.168.0.23",
            sysidcfg     => template("site/sysidcfg.erb"),
            path         => "/opt/zones/myzone",
            realhostname => "fully.qualified.domain.name"
          }

      The `sysidcfg` only matters on the first booting of the zone,
      so Puppet only checks for it at that time.}
  end

  newparam(:create_args) do
    desc "Arguments to the `zonecfg` create command.  This can be used to create branded zones."
  end

  newparam(:install_args) do
    desc "Arguments to the `zoneadm` install command.  This can be used to create branded zones."
  end

  newparam(:realhostname) do
    desc "The actual hostname of the zone."
  end

  # If Puppet is also managing the base dir or its parent dir, list them
  # both as prerequisites.
  autorequire(:file) do
    if @parameters.include? :path
      [@parameters[:path].value, ::File.dirname(@parameters[:path].value)]
    else
      nil
    end
  end

  # If Puppet is also managing the zfs filesystem which is the zone dataset
  # then list it as a prerequisite.  Zpool's get autorequired by the zfs
  # type.  We just need to autorequire the dataset zfs itself as the zfs type
  # will autorequire all of the zfs parents and zpool.
  autorequire(:zfs) do
    # Check if we have datasets in our zone configuration and autorequire each dataset
    self[:dataset] if @parameters.include? :dataset
  end

  def validate_ip(ip, name)
    IPAddr.new(ip) if ip
  rescue ArgumentError
    self.fail "'#{ip}' is an invalid #{name}"
  end

  def validate_exclusive(interface, address, router)
    return if !interface.nil? and address.nil?
    self.fail "only interface may be specified when using exclusive IP stack: #{interface}:#{address}"
  end
  def validate_shared(interface, address, router)
    self.fail "ip must contain interface name and ip address separated by a \":\"" if interface.nil? or address.nil?
    [address, router].each do |ip|
      validate_ip(address, "IP address") unless ip.nil?
    end
  end

  validate do
    return unless self[:ip]
    # self[:ip] reflects the type passed from proeprty:ip.should. If we
    # override it and pass @should, then we get an array here back.
    self[:ip].each do |ip|
      interface, address, router = ip.split(':')
      if self[:iptype] == :shared
        validate_shared(interface, address, router)
      else
        validate_exclusive(interface, address, router)
      end
    end
  end

  def retrieve
    provider.flush
    hash = provider.properties
    return setstatus(hash) unless hash.nil? or hash[:making_sure] == :absent
    # Return all properties as absent.
    return Hash[properties.map{|p| [p, :absent]} ]
  end

  # Take the results of a listing and set everything appropriately.
  def setstatus(hash)
    prophash = {}
    hash.each do |param, value|
      next if param == :name
      case self.class.attrtype(param)
      when :property
        # Only try to provide values for the properties we're managing
        prop = self.property(param)
        prophash[prop] = value if prop
      else
        self[param] = value
      end
    end
    prophash
  end
end
