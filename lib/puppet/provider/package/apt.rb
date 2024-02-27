# frozen_string_literal: true

require_relative '../../../puppet/util/package/version/range'
require_relative '../../../puppet/util/package/version/debian'

Puppet::Type.type(:package).provide :apt, :parent => :dpkg, :source => :dpkg do
  # Provide sorting functionality
  include Puppet::Util::Package
  DebianVersion = Puppet::Util::Package::Version::Debian
  VersionRange  = Puppet::Util::Package::Version::Range
  desc "Package management via `apt-get`.

    This provider supports the `install_options` attribute, which allows command-line flags to be passed to apt-get.
    These options should be specified as an array where each element is either a
     string or a hash."

  has_feature :versionable, :install_options, :virtual_packages, :version_ranges

  commands :aptget => "/usr/bin/apt-get"
  commands :aptcache => "/usr/bin/apt-cache"
  commands :aptmark => "/usr/bin/apt-mark"
  commands :preseed => "/usr/bin/debconf-set-selections"

  defaultfor 'os.family' => :debian

  ENV['DEBIAN_FRONTEND'] = "noninteractive"

  # disable common apt helpers to allow non-interactive package installs
  ENV['APT_LISTBUGS_FRONTEND'] = "none"
  ENV['APT_LISTCHANGES_FRONTEND'] = "none"

  def self.defaultto_allow_virtual
    false
  end

  def self.instances
    packages = super
    manual_marks = aptmark('showmanual').split("\n")
    packages.each do |package|
      package.mark = :manual if manual_marks.include?(package.name)
    end
    packages
  end

  def query
    hash = super

    if !%i[absent purged].include?(hash[:ensure]) && aptmark('showmanual', @resource[:name]).strip == @resource[:name]
      hash[:mark] = :manual
    end

    hash
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def mark
    @property_flush[:mark]
  end

  def mark=(value)
    @property_flush[:mark] = value
  end

  def flush
    # unless we are removing the package mark it if it hasn't already been marked
    if @property_flush
      unless @property_flush[:mark] || [:purge, :absent].include?(resource[:ensure])
        aptmark('manual', resource[:name])
      end
    end
  end

  # A derivative of DPKG; this is how most people actually manage
  # Debian boxes, and the only thing that differs is that it can
  # install packages from remote sites.

  # Double negation confuses Rubocop's Layout cops
  # rubocop:disable Layout
  def checkforcdrom
    have_cdrom = begin
                   !!(File.read("/etc/apt/sources.list") =~ /^[^#]*cdrom:/)
                 rescue
                   # This is basically pathological...
                   false
                 end
  # rubocop:enable Layout

    if have_cdrom and @resource[:allowcdrom] != :true
      raise Puppet::Error, _("/etc/apt/sources.list contains a cdrom source; not installing.  Use 'allowcdrom' to override this failure.")
    end
  end

  def best_version(should_range)
    versions = []

    output = aptcache :madison, @resource[:name]
    output.each_line do |line|
      is = line.split('|')[1].strip
      begin
        is_version = DebianVersion.parse(is)
        versions << is_version if should_range.include?(is_version)
      rescue DebianVersion::ValidationFailure
        Puppet.debug("Cannot parse #{is} as a debian version")
      end
    end

    return versions.sort.last if versions.any?

    Puppet.debug("No available version for package #{@resource[:name]} is included in range #{should_range}")
    should_range
  end

  # Install a package using 'apt-get'.  This function needs to support
  # installing a specific version.
  def install
    self.run_preseed if @resource[:responsefile]
    should = @resource[:ensure]

    if should.is_a?(String)
      begin
        should_range = VersionRange.parse(should, DebianVersion)

        unless should_range.is_a?(VersionRange::Eq)
          should = best_version(should_range)
        end
      rescue VersionRange::ValidationFailure, DebianVersion::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a debian version range, falling through")
      end
    end

    checkforcdrom
    cmd = %w[-q -y]

    config = @resource[:configfiles]
    if config
      if config == :keep
        cmd << "-o" << 'DPkg::Options::=--force-confold'
      else
        cmd << "-o" << 'DPkg::Options::=--force-confnew'
      end
    end

    str = @resource[:name]
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version and --force-yes option
      str += "=#{should}"
      cmd << "--force-yes"
    end

    cmd += install_options if @resource[:install_options]
    cmd << :install

    # rubocop:disable Style/RedundantCondition
    if source
      cmd << source
    else
      cmd << str
    end
    # rubocop:enable Style/RedundantCondition

    self.unhold if self.properties[:mark] == :hold
    begin
      aptget(*cmd)
    ensure
      self.hold if @resource[:mark] == :hold
    end

    # If a source file was specified, we must make sure the expected version was installed from specified file
    if source && !%i[present installed].include?(should)
      is = self.query
      raise Puppet::Error, _("Could not find package %{name}") % { name: self.name } unless is

      version = is[:ensure]

      raise Puppet::Error, _("Failed to update to version %{should}, got version %{version} instead") % { should: should, version: version } unless
        insync?(version)
    end
  end

  # What's the latest package version available?
  def latest
    output = aptcache :policy, @resource[:name]

    if output =~ /Candidate:\s+(\S+)\s/
      return $1
    else
      self.err _("Could not find latest version")
      return nil
    end
  end

  #
  # preseeds answers to dpkg-set-selection from the "responsefile"
  #
  def run_preseed
    response = @resource[:responsefile]
    if response && Puppet::FileSystem.exist?(response)
      self.info(_("Preseeding %{response} to debconf-set-selections") % { response: response })

      preseed response
    else
      self.info _("No responsefile specified or non existent, not preseeding anything")
    end
  end

  def uninstall
    self.run_preseed if @resource[:responsefile]
    args = ['-y', '-q']
    args << '--allow-change-held-packages' if self.properties[:mark] == :hold
    args << :remove << @resource[:name]
    aptget(*args)
  end

  def purge
    self.run_preseed if @resource[:responsefile]
    args = ['-y', '-q']
    args << '--allow-change-held-packages' if self.properties[:mark] == :hold
    args << :remove << '--purge' << @resource[:name]
    aptget(*args)
    # workaround a "bug" in apt, that already removed packages are not purged
    super
  end

  def install_options
    join_options(@resource[:install_options])
  end

  def insync?(is)
    # this is called after the generic version matching logic (insync? for the
    # type), so we only get here if should != is

    return false unless is && is != :absent

    # if 'should' is a range and 'is' a debian version we should check if 'should' includes 'is'
    should = @resource[:ensure]

    return false unless is.is_a?(String) && should.is_a?(String)

    begin
      should_range = VersionRange.parse(should, DebianVersion)
    rescue VersionRange::ValidationFailure, DebianVersion::ValidationFailure
      Puppet.debug("Cannot parse #{should} as a debian version range")
      return false
    end

    begin
      is_version = DebianVersion.parse(is)
    rescue DebianVersion::ValidationFailure
      Puppet.debug("Cannot parse #{is} as a debian version")
      return false
    end
    should_range.include?(is_version)
  end

  private

  def source
    @source ||= @resource[:source]
  end
end
