# frozen_string_literal: true

require_relative '../../../puppet/util/package/version/range'
require_relative '../../../puppet/util/package/version/rpm'
require_relative '../../../puppet/util/rpm_compare'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  # provides Rpm parsing and comparison
  include Puppet::Util::RpmCompare

  desc "Support via `yum`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to yum.
  These options should be specified as an array where each element is either a string or a hash."

  has_feature :install_options, :versionable, :virtual_packages, :install_only, :version_ranges

  RPM_VERSION       = Puppet::Util::Package::Version::Rpm
  RPM_VERSION_RANGE = Puppet::Util::Package::Version::Range

  commands :cmd => "yum", :rpm => "rpm"

  # Mixing confine statements, control expressions, and exception handling
  # confuses Rubocop's Layout cops, so we disable them entirely.
  # rubocop:disable Layout
  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end
  # rubocop:enable Layout

  defaultfor 'os.name' => :amazon
  defaultfor 'os.family' => :redhat, 'os.release.major' => (4..7).to_a

  def insync?(is)
    return false if [:purged, :absent].include?(is)
    return false if is.include?(self.class::MULTIVERSION_SEPARATOR) && !@resource[:install_only]

    should = @resource[:ensure]
    if should.is_a?(String)
      begin
        should_version = RPM_VERSION_RANGE.parse(should, RPM_VERSION)

        if should_version.is_a?(RPM_VERSION_RANGE::Eq)
          return super
        end
      rescue RPM_VERSION_RANGE::ValidationFailure, RPM_VERSION::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a RPM version range")
        return super
      end

      is.split(self.class::MULTIVERSION_SEPARATOR).any? do |version|
        begin
          is_version = RPM_VERSION.parse(version)
          should_version.include?(is_version)
        rescue RPM_VERSION::ValidationFailure
          Puppet.debug("Cannot parse #{is} as a RPM version")
        end
      end
    end
  end

  VERSION_REGEX = /^(?:(\d+):)?(\S+)-(\S+)$/

  def self.prefetch(packages)
    raise Puppet::Error, _("The yum provider can only be used as root") if Process.euid != 0

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
  # @param disablerepo [Array<String>] A list of repositories to disable for this query
  # @param enablerepo [Array<String>] A list of repositories to enable for this query
  # @param disableexcludes [Array<String>] A list of repository excludes to disable for this query
  # @return [Hash<Symbol, String>]
  def self.latest_package_version(package, disablerepo, enablerepo, disableexcludes)
    key = [disablerepo, enablerepo, disableexcludes]

    @latest_versions ||= {}
    if @latest_versions[key].nil?
      @latest_versions[key] = check_updates(disablerepo, enablerepo, disableexcludes)
    end

    if @latest_versions[key][package]
      @latest_versions[key][package].first
    end
  end

  # Search for all installed packages that have newer versions, given a
  # combination of repositories to enable and disable.
  #
  # @api private
  # @param disablerepo [Array<String>] A list of repositories to disable for this query
  # @param enablerepo [Array<String>] A list of repositories to enable for this query
  # @param disableexcludes [Array<String>] A list of repository excludes to disable for this query
  # @return [Hash<String, Array<Hash<String, String>>>] All packages that were
  #   found with a list of found versions for each package.
  # rubocop:disable Layout/SingleLineBlockChain
  def self.check_updates(disablerepo, enablerepo, disableexcludes)
    args = [command(:cmd), 'check-update']
    args.concat(disablerepo.map { |repo| ["--disablerepo=#{repo}"] }.flatten)
    args.concat(enablerepo.map { |repo| ["--enablerepo=#{repo}"] }.flatten)
    args.concat(disableexcludes.map { |repo| ["--disableexcludes=#{repo}"] }.flatten)

    output = Puppet::Util::Execution.execute(args, :failonfail => false, :combine => false)

    updates = {}
    case output.exitstatus
    when 100
      updates = parse_updates(output)
    when 0
      self.debug "#{command(:cmd)} check-update exited with 0; no package updates available."
    else
      self.warning _("Could not check for updates, '%{cmd} check-update' exited with %{status}") % { cmd: command(:cmd), status: output.exitstatus }
    end
    updates
  end
  # rubocop:enable Layout/SingleLineBlockChain

  def self.parse_updates(str)
    # Strip off all content that contains Obsoleting, Security: or Update
    body = str.partition(/^(Obsoleting|Security:|Update)/).first

    updates = Hash.new { |h, k| h[k] = [] }

    body.split(/^\s*\n/).each do |line|
      line.split.each_slice(3) do |tuple|
        next unless tuple[0].include?('.') && tuple[1] =~ VERSION_REGEX

        hash = update_to_hash(*tuple[0..1])
        # Create entries for both the package name without a version and a
        # version since yum considers those as mostly interchangeable.
        short_name = hash[:name]
        long_name  = "#{hash[:name]}.#{hash[:arch]}"
        updates[short_name] << hash
        updates[long_name] << hash
      end
    end
    updates
  end

  def self.update_to_hash(pkgname, pkgversion)
    # The pkgname string has two parts: name, and architecture. Architecture
    # is the portion of the string following the last "." character. All
    # characters preceding the final dot are the package name. Parse out
    # these two pieces of component data.
    name, _, arch = pkgname.rpartition('.')
    if name.empty?
      raise _("Failed to parse package name and architecture from '%{pkgname}'") % { pkgname: pkgname }
    end

    match = pkgversion.match(VERSION_REGEX)
    epoch = match[1] || '0'
    version = match[2]
    release = match[3]

    {
      :name => name,
      :epoch => epoch,
      :version => version,
      :release => release,
      :arch => arch,
    }
  end

  def self.clear
    @latest_versions = nil
  end

  def self.error_level
    '0'
  end

  def self.update_command
    # In yum both `upgrade` and `update` can be used to update packages
    # `yum upgrade` == `yum --obsoletes update`
    # Quote the DNF docs:
    # "Yum does this if its obsoletes config option is enabled but
    # the behavior is not properly documented and can be harmful."
    # So we'll stick with the safer option
    # If a user wants to remove obsoletes, they can use { :install_options => '--obsoletes' }
    # More detail here: https://bugzilla.redhat.com/show_bug.cgi?id=1096506
    'update'
  end

  def best_version(should)
    if should.is_a?(String)
      begin
        should_range = RPM_VERSION_RANGE.parse(should, RPM_VERSION)
        if should_range.is_a?(RPM_VERSION_RANGE::Eq)
          return should
        end
      rescue RPM_VERSION_RANGE::ValidationFailure, RPM_VERSION::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a RPM version range")
        return should
      end
      versions = []
      available_versions(@resource[:name], disablerepo, enablerepo, disableexcludes).each do |version|
        begin
          rpm_version = RPM_VERSION.parse(version)
          versions << rpm_version if should_range.include?(rpm_version)
        rescue RPM_VERSION::ValidationFailure
          Puppet.debug("Cannot parse #{version} as a RPM version")
        end
      end

      version = versions.sort.last if versions.any?

      if version
        version = version.to_s.sub(/^\d+:/, '')
        return version
      end

      Puppet.debug("No available version for package #{@resource[:name]} is included in range #{should_range}")
      should
    end
  end

  # rubocop:disable Layout/SingleLineBlockChain
  def available_versions(package_name, disablerepo, enablerepo, disableexcludes)
    args = [command(:cmd), 'list', package_name, '--showduplicates']
    args.concat(disablerepo.map { |repo| ["--disablerepo=#{repo}"] }.flatten)
    args.concat(enablerepo.map { |repo| ["--enablerepo=#{repo}"] }.flatten)
    args.concat(disableexcludes.map { |repo| ["--disableexcludes=#{repo}"] }.flatten)

    output = execute("#{args.compact.join(' ')} | sed -e '1,/Available Packages/ d' | awk '{print $2}'")
    output.split("\n")
  end
  # rubocop:enable Layout/SingleLineBlockChain

  def install
    wanted = @resource[:name]
    error_level = self.class.error_level
    update_command = self.class.update_command
    # If not allowing virtual packages, do a query to ensure a real package exists
    unless @resource.allow_virtual?
      execute([command(:cmd), '-d', '0', '-e', error_level, '-y', install_options, :list, wanted].compact)
    end

    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    operation = :install

    case should
    when :latest
      current_package = self.query
      if current_package && !current_package[:ensure].to_s.empty?
        operation = update_command
        self.debug "Ensuring latest, so using #{operation}"
      else
        self.debug "Ensuring latest, but package is absent, so using install"
        operation = :install
      end
      should = nil
    when true, :present, :installed
      # if we have been given a source and we were not asked for a specific
      # version feed it to yum directly
      if @resource[:source]
        wanted = @resource[:source]
        self.debug "Installing directly from #{wanted}"
      end
      should = nil
    when false, :absent
      # pass
      should = nil
    else
      if @resource[:source]
        # An explicit source was supplied, which means we're ensuring a specific
        # version, and also supplying the path to a package that supplies that
        # version.
        wanted = @resource[:source]
        self.debug "Installing directly from #{wanted}"
      else
        # No explicit source was specified, so add the package version
        should = best_version(should)
        wanted += "-#{should}"
        if wanted.scan(self.class::ARCH_REGEX)
          self.debug "Detected Arch argument in package! - Moving arch to end of version string"
          wanted.gsub!(/(.+)(#{self.class::ARCH_REGEX})(.+)/, '\1\3\2')
        end
      end
      current_package = self.query
      if current_package
        if @resource[:install_only]
          self.debug "Updating package #{@resource[:name]} from version #{current_package[:ensure]} to #{should} as install_only packages are never downgraded"
          operation = update_command
        elsif rpm_compare_evr(should, current_package[:ensure]) < 0
          self.debug "Downgrading package #{@resource[:name]} from version #{current_package[:ensure]} to #{should}"
          operation = :downgrade
        elsif rpm_compare_evr(should, current_package[:ensure]) > 0
          self.debug "Upgrading package #{@resource[:name]} from version #{current_package[:ensure]} to #{should}"
          operation = update_command
        end
      end
    end

    # Yum on el-4 and el-5 returns exit status 0 when trying to install a package it doesn't recognize;
    # ensure we capture output to check for errors.
    no_debug = Puppet.runtime[:facter].value('os.release.major').to_i > 5 ? ["-d", "0"] : []
    command = [command(:cmd)] + no_debug + ["-e", error_level, "-y", install_options, operation, wanted].compact
    output = execute(command)

    if output.to_s =~ /^No package #{wanted} available\.$/
      raise Puppet::Error, _("Could not find package %{wanted}") % { wanted: wanted }
    end

    # If a version was specified, query again to see if it is a matching version
    if should
      is = self.query
      raise Puppet::Error, _("Could not find package %{name}") % { name: self.name } unless is

      version = is[:ensure]
      # FIXME: Should we raise an exception even if should == :latest
      # and yum updated us to a version other than @param_hash[:ensure] ?
      raise Puppet::Error, _("Failed to update to version %{should}, got version %{version} instead") % { should: should, version: version } unless
        insync?(version)
    end
  end

  # What's the latest package version available?
  def latest
    upd = self.class.latest_package_version(@resource[:name], disablerepo, enablerepo, disableexcludes)
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current version is the latest
      self.debug "Yum didn't find updates, current version (#{properties[:ensure]}) is the latest"
      version = properties[:ensure]
      raise Puppet::DevError, _("Tried to get latest on a missing package") if version == :absent || version == :purged

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
    return [] unless options.is_a?(Enumerable)

    values =
      options.map do |repo|
        value =
          if repo.is_a?(String)
            next unless repo.include?('=')

            Hash[*repo.strip.split('=')] # make it a hash
          else
            repo
          end
        value[key]
      end
    values.compact.uniq
  end
end
