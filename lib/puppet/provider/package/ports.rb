Puppet::Type.type(:package).provide :ports, :parent => :freebsd, :source => :freebsd do
  desc "Support for FreeBSD's ports. Note that this, too, mixes packages and ports.

  `install_options` are passed to `portupgrade` command when installing,
  reinstalling or upgrading packages. You should always include
  `['-M','BATCH=yes']` options in your custom `install_options`. Some CLI flags
  are prepended internally to CLI and some flags given by user are internally
  removed when performing install, reinstall or upgrade actions.  Install
  always prepends `-N` and removes `-R` and `-f` if provided by user. Reinstall
  always prepends `-f` and removes `-N` flag if present. Upgrade always removes
  `-N` and `-f` if present in install_options.

  `uninstall_options` are passed to uninstall command. When the target system
  uses (old) `pkg_xxx` tools to manage packages, these options are passed to
  `pkg_deinstall` command. When the target system uses `pkgng` tools, then
  `uninstall_options` are passed to `pkg` command. If you define custom options
  for `pkg` (pkgng toolstack), you should always include the `-y` option (see
  pkg-delete(8) for details). Typical use case for `uninstall_options` is
  uninstalling packages recursively, that is uninstalling a package and all the
  other packages depending on this one. For `pkg_deinstall` the `%w{-r}` does
  the job and for `pkgng` it's achieved with `%w{-y -R}`.

  `package_settings` shall be a hash with port's option names as keys (all
  uppercase) and boolean values. This parameter defines options that you would
  normally set with make config command (the blue ncurses interface). Here is
  an example:

      package { 'www/apache22':
        ensure => present,
        package_settings => { 'SUEXEC' => true }
      }


  The options are written to `/var/db/ports/*/options.local` files (one file
  per package). For old `pkg_xxx` toolstack they are synchronized with what is
  found in `/var/db/ports/*/options{,.local}` files (possibly several files
  files per package). For the new `pkgng` system, they're synchronized with
  options returned by `pkg query`. If `package_settings` of an already installed
  package are out of sync with the ones prescribed in puppet manifests, the
  package gets reinstalled with the options taken from puppet manifests.
  "
  require 'puppet/util/package/ports'
  require 'puppet/util/package/ports/options'
  extend Puppet::Util::Package::Ports

  # Default options for {#install} method.
  self::DEFAULT_INSTALL_OPTIONS = %w{-N -M BATCH=yes}
  # Default options for {#reinstall} method.
  self::DEFAULT_REINSTALL_OPTIONS = %w{-r -f -M BATCH=yes}
  # Default options for {#update} method.
  self::DEFAULT_UPGRADE_OPTIONS = %w{-R -M BATCH=yes}

  # Detect whether the OS uses old pkg or the new pkgng.
  if pkgng_active? :pkg => '/usr/local/sbin/pkg'
    commands :portuninstall => '/usr/local/sbin/pkg',
             :pkg => '/usr/local/sbin/pkg'
    self::DEFAULT_UNINSTALL_OPTIONS =  %w{delete -y}
  else
    commands :portuninstall => '/usr/local/sbin/pkg_deinstall'
    self::DEFAULT_UNINSTALL_OPTIONS =  %w{}
  end
  debug "Selecting '#{command(:portuninstall)}' command as package uninstaller"

  commands :portupgrade   => "/usr/local/sbin/portupgrade",
           :portversion   => "/usr/local/sbin/portversion",
           :make          => "/usr/bin/make"

  defaultfor :operatingsystem => :freebsd

  has_feature :install_options
  has_feature :uninstall_options

  # I hate ports
  %w{INTERACTIVE UNAME}.each do |var|
    ENV.delete(var) if ENV.include?(var)
  end

  # note, portsdir and port_dbdir are defined in module
  # Puppet::Util::Package::Ports::Functions
  confine :exists => [ portsdir, port_dbdir ]

  def pkgng_active?
    self.class.pkgng_active?
  end

  def self.instances(names=nil)
    split_record = names ? lambda{|r| [r[1][:pkgname],r[1]]} :
                           lambda{|r| [r[:pkgname], r]}

    fields = Puppet::Util::Package::Ports::PkgRecord.default_fields
    options = if pkgng_active?
      # here, with pkgng we have more reliable and efficient way to retrieve
      # build options
      fields -= [:options]
      options_class = Puppet::Util::Package::Ports::Options
      options_class.query_pkgng('%o',nil,{:pkg => command(:pkg)})
    else
      {}
    end

    records = {}
    # find installed packages
    search_packages(names,fields) do |record|
      name, record = split_record.call(record)
      records[name] ||= Array.new
      records[name] << record
    end
    # create provider instances
    packages = []
    with_unique('installed ports', records) do |pkgname,record|
      unless record[:portorigin] and ['<','=','>'].include?(record[:portstatus])
        record.delete(:portorigin) if record[:portorigin]
        warning "Could not find port for installed package '#{pkgname}'." +
                "Build options and upgrades will not work for this package."
      end
      # if portorigin is unavailable, use pkgname to identify the package,
      # this allows to at least uninstall packages that are currently
      # installed but their ports were removed from ports tree
      package = new({
        :name => record[:portorigin] || record[:pkgname],
        :ensure => record[:pkgversion],
        :package_settings => options[record[:portorigin]] || record[:options] || {},
        :provider => self.name
      })
      package.assign_port_attributes(record)
      packages << package
    end
    packages
  end

  def self.prefetch(packages)
    # already installed packages
    newpkgs = packages.keys
    instances.each do |prov|
      if pkg = (packages[prov.name] || packages[prov.portorigin] ||
                packages[prov.pkgname] || packages[prov.portname])
        newpkgs -= [prov.name, prov.portorigin, prov.pkgname, prov.portname]
        pkg.provider = prov
      end
    end
    # we prefetch also not installed ports to save time; this way we perform
    # only two or three calls to `make search` (for up to 60 packages) instead
    # of 3xN calls (in query()) for N packages
    records = {}
    search_ports(newpkgs) do |name,record|
      records[name] ||= []
      records[name] << record
    end
    with_unique('ports', records) do |name,record|
      prov = new({:name => record[:portorigin], :ensure => :absent})
      prov.assign_port_attributes(record)
      packages[name].provider = prov
    end
  end

  def self.with_unique(what, records)
    records.each do |name,array|
      record = array.last
      if (len = array.length) > 1
        warning "Found #{len} #{what} named '#{name}': " +
          "#{array.map{|r| "'#{r[:portorigin]}'"}.join(', ')}. " +
          "Only '#{record[:portorigin]}' will be ensured."
      end
      yield name, record
    end
  end
  private_class_method :with_unique

  self::PORT_ATTRIBUTES = [
    :pkgname,
    :portorigin,
    :portname,
    :portstatus,
    :portinfo,
    :options_file,
    :options_files
  ]

  self::PORT_ATTRIBUTES.each do |attr|
    define_method(attr) do
      var = instance_variable_get("@#{attr}".intern)
      unless var
        raise Puppet::Error, "Attribute '#{attr}' not assigned for package '#{self.name}'."
      end
      var
    end
  end

  # assign attributes from hash (but only these listed in PORT_ATTRIBUTES)
  def assign_port_attributes(record)
    (record.keys & self.class::PORT_ATTRIBUTES).each do |key|
      instance_variable_set("@#{key}".intern, record[key])
    end
  end
  
  # needed by Puppet::Type::Package
  def package_settings_validate(opts)
    return true if not opts # options not defined
    options_class = Puppet::Util::Package::Ports::Options
    unless opts.is_a?(Hash) or opts.is_a?(options_class)
      fail ArgumentError, "#{opts.inspect} of type #{opts.class} is not an " +
                          "options Hash (for $package_settings)"
    end
    opts.each do |k, v|
      unless options_class.option_name?(k)
        fail ArgumentError, "#{k.inspect} is not a valid option name (for " +
                            "$package_settings)"
      end
      unless options_class.option_value?(v)
        fail ArgumentError, "#{v.inspect} is not a valid option value (for " +
                            "$package_settings)"
      end
    end
    true
  end

  # needed by Puppet::Type::Package
  def package_settings_munge(opts)
    unless opts.is_a?(Puppet::Util::Package::Ports::Options)
      Puppet::Util::Package::Ports::Options[opts || {}]
    else
      opts
    end
  end

  # needed by Puppet::Type::Package
  def package_settings_insync?(should, is)
    unless should.is_a?(Puppet::Util::Package::Ports::Options) and
               is.is_a?(Puppet::Util::Package::Ports::Options)
      return false
    end
    is.select {|k,v| should.keys.include? k} == should
  end

  # needed by Puppet::Type::Package
  def package_settings_should_to_s(should, newvalue)
    if newvalue.is_a?(Puppet::Util::Package::Ports::Options)
      Puppet::Util::Package::Ports::Options[newvalue.sort].inspect
    else
      newvalue.inspect
    end
  end

  # needed by Puppet::Type::Package
  def package_settings_is_to_s(should, currentvalue)
    if currentvalue.is_a?(Puppet::Util::Package::Ports::Options)
      hash = currentvalue.select{|k,v| should.keys.include? k}.sort
      Puppet::Util::Package::Ports::Options[hash].inspect
    else
      currentvalue.inspect
    end
  end

  # Interface method required by package resource type. Returns the current
  # value of package_settings property.
  def package_settings
    properties[:package_settings]
  end

  # Reinstall package to deploy (new) build options.
  def package_settings=(opts)
    reinstall(opts)
  end

  def sync_package_settings(should)
    return if not should
    is = properties[:package_settings]
    unless package_settings_insync?(should, is)
      should.save(options_file, { :pkgname => pkgname })
    end
  end
  private :sync_package_settings

  def revert_package_settings
    if options = properties[:package_settings]
      debug "Reverting options in #{options_file}"
      properties[:package_settings].save(options_file, { :pkgname => pkgname })
    end
  end
  private :revert_package_settings

  # Return portupgrade's CLI options for use within the {#install} method.
  def install_options
    # In an ideal world we would have all these parameters independent:
    # install_options, reinstall_options, upgrade_options, uninstall_options.
    # In this world we must live with install_options and uninstall_options
    # only.
    ops = resource[:install_options]
    # We always add -N to command line to indicate, that we want to install new
    # package only when it's not installed. This idea is inherited from
    # original implementation of ports provider.
    # We always remove -R and -f from command line, as these options have
    # no clear meaning when -N is used (either, they have no effect with -R or
    # they can mess-up your OS - I haven't checked this).
    prepare_options(ops, self.class::DEFAULT_INSTALL_OPTIONS, %w{-N}, %w{-R -f})
  end

  # Return portupgrade's CLI options for use within the {#reinstall} method.
  def reinstall_options
    ops = resource[:install_options]
    # We always remove -N from command line, as this flag breaks the upgrade
    # procedure (-N indicates that one wants to install new package which is
    # currently not installed, or to skip installation if it's installed; the
    # reinstall method is invoked on already installed packages only).
    # We always add -f to command line, to not silently skip reinstall (without
    # this reinstalls are silently discarded)
    prepare_options(ops, self.class::DEFAULT_REINSTALL_OPTIONS, %w{-f}, %w{-N})
  end

  # Return portupgrade's CLI options for use within the {#update} method.
  def upgrade_options
    ops = resource[:install_options]
    # We always remove -N from command line, as this flag breaks the upgrade
    # procedure (-N indicates that one wants to install package which is not
    # currently installed, or to skip installation if it's installed; the
    # upgrade method is invoked on already installed packages only).
    # We always remove -f from command line, as the upgrade procedure shouldn't
    # depend on it (upgrade should only be used to install newer versions,
    # which must work without -f)
    prepare_options(ops, self.class::DEFAULT_UPGRADE_OPTIONS, %w{}, %w{-f -N})
  end

  # Return portuninstall's CLI options for use within the {#uninstall} method.
  def uninstall_options
    # For pkgng we always prepend the 'delete' command to options.
    ops = resource[:uninstall_options]
    if pkgng_active?
      prepare_options(ops, self.class::DEFAULT_UNINSTALL_OPTIONS, %w{delete})
    else
      prepare_options(ops, self.class::DEFAULT_UNINSTALL_OPTIONS)
    end
  end

  # Prepare options for install, reinstall, upgrade and uninstall methods.
  #
  # @param options [Array|nil]
  # @param defaults [Array] default flags used when options are not provided,
  # @param extra [Array] extra flags added to user-defined options,
  # @param deny [Array] flags that must be removed from user-defined options,
  # @return [Array] modified options
  #
  # Returns defaults if options are not provided by user. If options are
  # provided, handle the '{option => value}' pairs, flatten options array
  # append extra flags defined by caller and remove denied flags defined by the
  # caller.
  #
  def prepare_options(options, defaults, extra = [], deny = [])
    return defaults unless options

    # handle {option => value} hashes and flatten nested arrays
    options = options.collect do |val|
      case val
      when Hash
        val.keys.sort.collect { |k| "#{k}=#{val[k]}" }
      else
        val
      end
    end.flatten

    # add some flags we think are mandatory for the given operation
    extra.each { |f| options.unshift(f) unless options.include?(f) }
    options = options - deny
    options
  end

  # For internal use only
  def do_portupgrade(name, args, package_settings)
    cmd = args << name
    begin
      sync_package_settings(package_settings)
      output = portupgrade(*cmd)
      if output =~ /\*\* No such /
        raise Puppet::ExecutionFailure, "Could not find package #{name}"
      end
    rescue
      revert_package_settings
      raise
    end
  end
  private :do_portupgrade

  # install new package (only if it's not installed).
  def install
    # we prefetched also not installed ports so @portorigin may be present
    name = @portorigin || resource[:name]
    do_portupgrade name, install_options, resource[:package_settings]
  end

  # reinstall already installed package with new options.
  def reinstall(options)
    if @portorigin
      do_portupgrade portorigin, reinstall_options, options
    else
      warning "Could not reinstall package '#{name}' which has no port origin."
    end
  end

  # upgrade already installed package.
  def update
    if properties[:ensure] == :absent
      install
    else
      if @portorigin
        do_portupgrade portorigin, upgrade_options, resource[:package_settings]
      else
        warning "Could not upgrade package '#{name}' which has no port origin."
      end
    end
  end

  # uninstall already installed package
  def uninstall
    cmd = uninstall_options << self.pkgname
    portuninstall(*cmd)
  end

  # If there are multiple packages, we only use the last one
  def latest
    # If there's no "latest" version, we just return a placeholder
    result = :latest
    status, info, portname, oldversion = [nil, nil, nil, nil]
    oldversion = properties[:ensure]
    case portstatus
    when '>','='
      result = oldversion
    when '<'
      if m = portinfo.match(/\((\w+) has (.+)\)/)
        source, newversion = m[1,2]
        debug "Newer version in #{source}"
        result = newversion
      else
        raise Puppet::Error, "Could not match version info #{portinfo.inspect}."
      end
    when '?'
      warning "The installed package '#{pkgname}' does not appear in the " +
        "ports database nor does its port directory exist."
    when '!'
      warning "The installed package '#{pkgname}' does not appear in the " +
        "ports database, the port directory actually exists, but the latest " +
        "version number cannot be obtained."
    when '#'
      warning "The installed package '#{pkgname}' does not have an origin recorded."
    else
      warning "Invalid status flag #{portstatus.inspect} for package " +
        "'#{pkgname}' (returned by portversion command)."
    end
    result
  end

  def query
    # support names, portorigin, pkgname and portname
    (inst = self.class.instances([name]).last) ? inst.properties : nil
  end
end
