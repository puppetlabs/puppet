# frozen_string_literal: true

Puppet::Type.type(:package).provide :zypper, :parent => :rpm, :source => :rpm do
  desc "Support for SuSE `zypper` package manager. Found in SLES10sp2+ and SLES11.

    This provider supports the `install_options` attribute, which allows command-line flags to be passed to zypper.
    These options should be specified as an array where each element is either a
    string or a hash."

  has_feature :versionable, :install_options, :virtual_packages

  commands :zypper => "/usr/bin/zypper"

  defaultfor 'os.name' => [:suse, :sles, :sled, :opensuse]
  confine    'os.name' => [:suse, :sles, :sled, :opensuse]

  # @api private
  # Reset the latest version hash to nil
  # needed for spec tests to clear cached value
  def self.reset!
    @latest_versions = nil
  end

  def self.latest_package_version(package)
    if @latest_versions.nil?
      @latest_versions = list_updates
    end

    @latest_versions[package]
  end

  def self.list_updates
    output = zypper 'list-updates'

    avail_updates = {}

    # split up columns
    output.lines.each do |line|
      pkg_ver = line.split(/\s*\|\s*/)
      # ignore zypper headers
      next unless pkg_ver[0] == 'v'

      avail_updates[pkg_ver[2]] = pkg_ver[4]
    end

    avail_updates
  end

  # on zypper versions <1.0, the version option returns 1
  # some versions of zypper output on stderr
  def zypper_version
    cmd = [self.class.command(:zypper), "--version"]
    execute(cmd, { :failonfail => false, :combine => true })
  end

  def best_version(should)
    if should.is_a?(String)
      begin
        should_range = Puppet::Util::Package::Version::Range.parse(should, Puppet::Util::Package::Version::Rpm)
      rescue Puppet::Util::Package::Version::Range::ValidationFailure, Puppet::Util::Package::Version::Rpm::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a RPM version range")
        return should
      end

      if should_range.is_a?(Puppet::Util::Package::Version::Range::Eq)
        return should
      end

      versions = []

      output = zypper('search', '--match-exact', '--type', 'package', '--uninstalled-only', '-s', @resource[:name])
      output.lines.each do |line|
        pkg_ver = line.split(/\s*\|\s*/)
        next unless pkg_ver[1] == @resource[:name]

        begin
          rpm_version = Puppet::Util::Package::Version::Rpm.parse(pkg_ver[3])

          versions << rpm_version if should_range.include?(rpm_version)
        rescue Puppet::Util::Package::Version::Rpm::ValidationFailure
          Puppet.debug("Cannot parse #{pkg_ver[3]} as a RPM version")
        end
      end

      return versions.sort.last if versions.any?

      Puppet.debug("No available version for package #{@resource[:name]} is included in range #{should_range}")
      should
    end
  end

  # Install a package using 'zypper'.
  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]

    # XXX: We don't actually deal with epochs here.
    case should
    when true, false, Symbol
      should = nil
    else
      # Add the package version
      should = best_version(should)
      wanted = "#{wanted}-#{should}"
    end

    # This has been tested with following zypper versions
    # SLE 10.4: 0.6.201
    # SLE 11.3: 1.6.307
    # SLE 12.0: 1.11.14
    # Assume that this will work on newer zypper versions

    # extract version numbers and convert to integers
    major, minor, patch = zypper_version.scan(/\d+/).map { |x| x.to_i }
    self.debug "Detected zypper version #{major}.#{minor}.#{patch}"

    # zypper version < 1.0 does not support --quiet flag
    if major < 1
      quiet = '--terse'
    else
      quiet = '--quiet'
    end

    inst_opts = []
    inst_opts = install_options if resource[:install_options]

    options = []
    options << quiet
    options << '--no-gpg-check' unless inst_opts.delete('--no-gpg-check').nil?
    options << '--no-gpg-checks' unless inst_opts.delete('--no-gpg-checks').nil?
    options << :install

    # zypper 0.6.13 (OpenSuSE 10.2) does not support auto agree with licenses
    options << '--auto-agree-with-licenses' unless major < 1 and minor <= 6 and patch <= 13
    options << '--no-confirm'
    options += inst_opts unless inst_opts.empty?

    # Zypper 0.6.201 doesn't recognize '--name'
    # It is unclear where this functionality was introduced, but it
    # is present as early as 1.0.13
    options << '--name' unless major < 1 || @resource.allow_virtual? || should
    options << wanted

    zypper(*options)

    unless self.query
      raise Puppet::ExecutionFailure, _("Could not find package %{name}") % { name: self.name }
    end
  end

  # What's the latest package version available?
  def latest
    return self.class.latest_package_version(@resource[:name]) ||
           # zypper didn't find updates, pretend the current
           # version is the latest
           @property_hash[:ensure]
  end

  def update
    # zypper install can be used for update, too
    self.install
  end

  def uninstall
    # extract version numbers and convert to integers
    major, minor, _ = zypper_version.scan(/\d+/).map { |x| x.to_i }

    if major < 1
      super
    else
      options = [:remove, '--no-confirm']
      if major == 1 && minor < 6
        options << '--force-resolution'
      end

      options << @resource[:name]

      zypper(*options)
    end
  end

  def insync?(is)
    return false if [:purged, :absent].include?(is)

    should = @resource[:ensure]
    if should.is_a?(String)
      begin
        should_version = Puppet::Util::Package::Version::Range.parse(should, Puppet::Util::Package::Version::Rpm)
        if should_version.is_a?(RPM_VERSION_RANGE::Eq)
          return super
        end
      rescue Puppet::Util::Package::Version::Range::ValidationFailure, Puppet::Util::Package::Version::Rpm::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a RPM version range")
        return super
      end

      begin
        is_version = Puppet::Util::Package::Version::Rpm.parse(is)
        should_version.include?(is_version)
      rescue Puppet::Util::Package::Version::Rpm::ValidationFailure
        Puppet.debug("Cannot parse #{is} as a RPM version")
      end
    end
  end
end
