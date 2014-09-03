require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to yum.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :install_options, :versionable, :virtual_packages

  commands :yum => "yum", :rpm => "rpm", :python => "python"

  self::YUMHELPER = File::join(File::dirname(__FILE__), "yumhelper.py")

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
  # @return [Hash<Symbol, String>]
  def self.latest_package_version(package, enablerepo, disablerepo)

    key = [enablerepo, disablerepo]

    @latest_versions ||= {}
    if @latest_versions[key].nil?
      @latest_versions[key] = fetch_latest_versions(enablerepo, disablerepo)
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
  # @return [Hash<String, Array<Hash<String, String>>>] All packages that were
  #   found with a list of found versions for each package.
  def self.fetch_latest_versions(enablerepo, disablerepo)
    latest_versions = Hash.new {|h, k| h[k] = []}

    args = [self::YUMHELPER]
    args.concat(enablerepo.map { |repo| ['-e', repo] }.flatten)
    args.concat(disablerepo.map { |repo| ['-d', repo] }.flatten)

    python(args).scan(/^_pkg (.*)$/) do |match|
      hash = nevra_to_hash(match[0])

      # Create entries for both the package name without a version and a
      # version since yum considers those as mostly interchangeable.
      short_name = hash[:name]
      long_name  = "#{hash[:name]}.#{hash[:arch]}"

      latest_versions[short_name] << hash
      latest_versions[long_name]  << hash
    end
    latest_versions
  end

  def self.clear
    @latest_versions = nil
  end

  def install
    wanted = @resource[:name]
    # If not allowing virtual packages, do a query to ensure a real package exists
    unless @resource.allow_virtual?
      yum *['-d', '0', '-e', '0', '-y', install_options, :list, wanted].compact
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
      is = self.query
      if is && Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
        operation = :downgrade
      end
    end

    args = ["-d", "0", "-e", "0", "-y", install_options, operation, wanted].compact
    yum *args


    # If a version was specified, query again to see if it is a matching version
    if should
      is = self.query
      raise Puppet::Error, "Could not find package #{self.name}" unless is

      # FIXME: Should we raise an exception even if should == :latest
      # and yum updated us to a version other than @param_hash[:ensure] ?
      raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if should != is[:ensure]
    end
  end

  # What's the latest package version available?
  def latest
    upd = self.class.latest_package_version(@resource[:name], enablerepo, disablerepo)
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current
      # version is the latest
      raise Puppet::DevError, "Tried to get latest on a missing package" if properties[:ensure] == :absent
      return properties[:ensure]
    end
  end

  def update
    # Install in yum can be used for update, too
    self.install
  end

  def purge
    yum "-y", :erase, @resource[:name]
  end

  # @deprecated
  def latest_info
    Puppet.deprecation_warning("#{self.class}##{__method__} is deprecated and is no longer used.")
    @latest_info
  end

  # @deprecated
  def latest_info=(latest)
    Puppet.deprecation_warning("#{self.class}##{__method__} is deprecated and is no longer used.")
    @latest_info = latest
  end

  private

  def enablerepo
    scan_options(resource[:install_options], '--enablerepo')
  end

  def disablerepo
    scan_options(resource[:install_options], '--disablerepo')
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
