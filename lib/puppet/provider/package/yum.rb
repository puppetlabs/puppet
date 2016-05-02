Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to yum.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :install_options, :versionable, :virtual_packages

  commands :cmd => "yum", :rpm => "rpm"

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :osfamily => :redhat

  def self.prefetch(packages)
    raise Puppet::Error, "The yum provider can only be used as root" if Process.euid != 0
    super
  end

  # Retrieve the latest package version information for a given package name
  # and combination of repos to enable and disable.
  #
  # @note If multiple package versions are defined (such as in the case where a
  #   package is built for multiple architectures), the first package found
  #   will be used.
  #
  # @api private
  # @param package [String] The name of the package to query
  # @param enablerepo [Array<String>] A list of repositories to enable for this query
  # @param disablerepo [Array<String>] A list of repositories to disable for this query
  # @param disableexcludes [Array<String>] A list of repository excludes to disable for this query
  # @return [Hash<Symbol, String>]
  def self.latest_package_version(package, enablerepo, disablerepo, disableexcludes)

    key = [enablerepo, disablerepo, disableexcludes]

    @latest_versions ||= {}
    if @latest_versions[key].nil?
      @latest_versions[key] = check_updates(enablerepo, disablerepo, disableexcludes)
    end

    if @latest_versions[key][package]
      @latest_versions[key][package].first
    end
  end

  # Search for all installed packages that have newer versions, given a
  # combination of repositories to enable and disable.
  #
  # @api private
  # @param enablerepo [Array<String>] A list of repositories to enable for this query
  # @param disablerepo [Array<String>] A list of repositories to disable for this query
  # @param disableexcludes [Array<String>] A list of repository excludes to disable for this query
  # @return [Hash<String, Array<Hash<String, String>>>] All packages that were
  #   found with a list of found versions for each package.
  def self.check_updates(enablerepo, disablerepo, disableexcludes)
    args = [command(:cmd), 'check-update']
    args.concat(enablerepo.map { |repo| ["--enablerepo=#{repo}"] }.flatten)
    args.concat(disablerepo.map { |repo| ["--disablerepo=#{repo}"] }.flatten)
    args.concat(disableexcludes.map { |repo| ["--disableexcludes=#{repo}"] }.flatten)

    output = Puppet::Util::Execution.execute(args, :failonfail => false, :combine => false)

    updates = {}
    if output.exitstatus == 100
      updates = parse_updates(output)
    elsif output.exitstatus == 0
      self.debug "#{command(:cmd)} check-update exited with 0; no package updates available."
    else
      self.warning "Could not check for updates, '#{command(:cmd)} check-update' exited with #{output.exitstatus}"
    end
    updates
  end

  def self.parse_updates(str)
    # Strip off all content before the first blank line
    body = str.partition(/^\s*\n/m).last

    updates = Hash.new { |h, k| h[k] = [] }
    body.split.each_slice(3) do |tuple|
      break if tuple[0] =~ /^(Obsoleting|Security:|Update)/
      hash = update_to_hash(*tuple[0..1])
      # Create entries for both the package name without a version and a
      # version since yum considers those as mostly interchangeable.
      short_name = hash[:name]
      long_name  = "#{hash[:name]}.#{hash[:arch]}"

      updates[short_name] << hash
      updates[long_name] << hash
    end

    updates
  end

  def self.update_to_hash(pkgname, pkgversion)
    name, arch = pkgname.split('.')

    match = pkgversion.match(/^(?:(\d+):)?(\S+)-(\S+)$/)
    epoch = match[1] || '0'
    version = match[2]
    release = match[3]

    {
      :name => name,
      :epoch => epoch,
      :version => version,
      :release => release,
      :arch    => arch,
    }
  end

  def self.clear
    @latest_versions = nil
  end

  def self.error_level
    '0'
  end

  def install
    wanted = @resource[:name]
    error_level = self.class.error_level
    # If not allowing virtual packages, do a query to ensure a real package exists
    unless @resource.allow_virtual?
      execute([command(:cmd), '-d', '0', '-e', error_level, '-y', install_options, :list, wanted].compact)
    end

    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    operation = :install

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      if wanted.scan(ARCH_REGEX)
        self.debug "Detected Arch argument in package! - Moving arch to end of version string"
        wanted.gsub!(/(.+)(#{ARCH_REGEX})(.+)/,'\1\3\2')
      end

      is = self.query
      if is && rpm_compareEVR(rpm_parse_evr(should), rpm_parse_evr(is[:ensure])) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
        operation = :downgrade
      end
    end

    # Yum on el-4 and el-5 returns exit status 0 when trying to install a package it doesn't recognize;
    # ensure we capture output to check for errors.
    no_debug = if Facter.value(:operatingsystemmajrelease).to_i > 5 then ["-d", "0"] else [] end
    command = [command(:cmd)] + no_debug + ["-e", error_level, "-y", install_options, operation, wanted].compact
    output = execute(command)

    if output =~ /^No package #{wanted} available\.$/
      raise Puppet::Error, "Could not find package #{wanted}"
    end

    # If a version was specified, query again to see if it is a matching version
    if should
      is = self.query
      raise Puppet::Error, "Could not find package #{self.name}" unless is

      # FIXME: Should we raise an exception even if should == :latest
      # and yum updated us to a version other than @param_hash[:ensure] ?
      vercmp_result = rpm_compareEVR(rpm_parse_evr(should), rpm_parse_evr(is[:ensure]))
      raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if vercmp_result != 0
    end
  end

  # What's the latest package version available?
  def latest
    upd = self.class.latest_package_version(@resource[:name], enablerepo, disablerepo, disableexcludes)
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current version is the latest
      version = properties[:ensure]
      raise Puppet::DevError, "Tried to get latest on a missing package" if version == :absent || version == :purged
      return version
    end
  end

  def update
    # Install in yum can be used for update, too
    self.install
  end

  def purge
    execute([command(:cmd), "-y", :erase, @resource[:name]])
  end

  private

  def enablerepo
    scan_options(resource[:install_options], '--enablerepo')
  end

  def disablerepo
    scan_options(resource[:install_options], '--disablerepo')
  end

  def disableexcludes
    scan_options(resource[:install_options], '--disableexcludes')
  end

  # Scan a structure that looks like the package type 'install_options'
  # structure for all hashes that have a specific key.
  #
  # @api private
  # @param options [Array<String | Hash>, nil] The options structure. If the
  #   options are nil an empty array will be returned.
  # @param key [String] The key to look for in all contained hashes
  # @return [Array<String>] All hash values with the given key.
  def scan_options(options, key)
    return [] if options.nil?
    options.inject([]) do |repos, opt|
      if opt.is_a? Hash and opt[key]
        repos << opt[key]
      end
      repos
    end
  end
end
