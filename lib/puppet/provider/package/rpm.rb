# frozen_string_literal: true

require_relative '../../../puppet/provider/package'
require_relative '../../../puppet/util/rpm_compare'

# RPM packaging.  Should work anywhere that has rpm installed.
Puppet::Type.type(:package).provide :rpm, :source => :rpm, :parent => Puppet::Provider::Package do
  # provides Rpm parsing and comparison
  include Puppet::Util::RpmCompare

  desc "RPM packaging support; should work anywhere with a working `rpm`
    binary.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to rpm.
    These options should be specified as an array where each element is either a string or a hash."

  has_feature :versionable
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :virtual_packages
  has_feature :install_only

  # Note: self:: is required here to keep these constants in the context of what will
  # eventually become this Puppet::Type::Package::ProviderRpm class.
  # The query format by which we identify installed packages
  self::NEVRA_FORMAT = %q(%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n)
  self::NEVRA_REGEX  = %r{^'?(\S+) (\S+) (\S+) (\S+) (\S+)$}
  self::NEVRA_FIELDS = [:name, :epoch, :version, :release, :arch]
  self::MULTIVERSION_SEPARATOR = "; "

  commands :rpm => "rpm"

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

  def self.current_version
    return @current_version unless @current_version.nil?

    output = rpm "--version"
    @current_version = output.gsub('RPM version ', '').strip
  end

  # rpm < 4.1 does not support --nosignature
  def self.nosignature
    '--nosignature' unless Puppet::Util::Package.versioncmp(current_version, '4.1') < 0
  end

  # rpm < 4.0.2 does not support --nodigest
  def self.nodigest
    '--nodigest' unless Puppet::Util::Package.versioncmp(current_version, '4.0.2') < 0
  end

  def self.instances
    packages = []

    # list out all of the packages
    begin
      execpipe("#{command(:rpm)} -qa #{nosignature} #{nodigest} --qf '#{self::NEVRA_FORMAT}' | sort") { |process|
        # now turn each returned line into a package object
        nevra_to_multiversion_hash(process).each { |hash| packages << new(hash) }
      }
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, _("Failed to list packages"), $!.backtrace
    end

    packages
  end

  # Find the fully versioned package name and the version alone. Returns
  # a hash with entries :instance => fully versioned package name, and
  # :ensure => version-release
  def query
    # NOTE: Prior to a fix for issue 1243, this method potentially returned a cached value
    # IF YOU CALL THIS METHOD, IT WILL CALL RPM
    # Use get(:property) to check if cached values are available
    cmd = ["-q", @resource[:name], "#{self.class.nosignature}", "#{self.class.nodigest}", "--qf", "#{self.class::NEVRA_FORMAT}"]

    begin
      output = rpm(*cmd)
    rescue Puppet::ExecutionFailure
      return nil unless @resource.allow_virtual?

      # rpm -q exits 1 if package not found
      # retry the query for virtual packages
      cmd << '--whatprovides'
      begin
        output = rpm(*cmd)
      rescue Puppet::ExecutionFailure
        # couldn't find a virtual package either
        return nil
      end
    end
    @property_hash.update(self.class.nevra_to_multiversion_hash(output))

    @property_hash.dup
  end

  # Here we just retrieve the version from the file specified in the source.
  def latest
    source = @resource[:source]
    unless source
      @resource.fail _("RPMs must specify a package source")
    end

    cmd = [command(:rpm), "-q", "--qf", "#{self.class::NEVRA_FORMAT}", "-p", source]
    h = self.class.nevra_to_multiversion_hash(execute(cmd))
    h[:ensure]
  rescue Puppet::ExecutionFailure => e
    raise Puppet::Error, e.message, e.backtrace
  end

  def install
    source = @resource[:source]
    unless source
      @resource.fail _("RPMs must specify a package source")
    end

    version = @property_hash[:ensure]

    # RPM gets upset if you try to install an already installed package
    return if @resource.should(:ensure) == version || (@resource.should(:ensure) == :latest && version == latest)

    flag = ["-i"]
    flag = ["-U", "--oldpackage"] if version && (version != :absent && version != :purged)
    flag += install_options if resource[:install_options]
    rpm flag, source
  end

  def uninstall
    query
    # If version and release (or only version) is specified in the resource,
    # uninstall using them, otherwise uninstall using only the name of the package.
    name    = get(:name)
    version = get(:version)
    release = get(:release)
    nav = "#{name}-#{version}"
    nvr = "#{nav}-#{release}"
    if @resource[:name].start_with? nvr
      identifier = nvr
    elsif @resource[:name].start_with? nav
      identifier = nav
    elsif @resource[:install_only]
      identifier = get(:ensure).split(self.class::MULTIVERSION_SEPARATOR).map { |ver| "#{name}-#{ver}" }
    else
      identifier = name
    end
    # If an arch is specified in the resource, uninstall that arch,
    # otherwise uninstall the arch returned by query.
    # If multiple arches are installed and arch is not specified,
    # this will uninstall all of them after successive runs.
    #
    # rpm prior to 4.2.1 cannot accept architecture as part of the package name.
    unless Puppet::Util::Package.versioncmp(self.class.current_version, '4.2.1') < 0
      arch = ".#{get(:arch)}"
      if @resource[:name].end_with? arch
        identifier += arch
      end
    end

    flag = ['-e']
    flag += uninstall_options if resource[:uninstall_options]
    rpm flag, identifier
  end

  def update
    self.install
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end

  def insync?(is)
    return false if [:purged, :absent].include?(is)
    return false if is.include?(self.class::MULTIVERSION_SEPARATOR) && !@resource[:install_only]

    should = resource[:ensure]
    is.split(self.class::MULTIVERSION_SEPARATOR).any? do |version|
      0 == rpm_compare_evr(should, version)
    end
  end

  private

  # @param line [String] one line of rpm package query information
  # @return [Hash] of NEVRA_FIELDS strings parsed from package info
  # or an empty hash if we failed to parse
  # @api private
  def self.nevra_to_hash(line)
    line.strip!
    hash = {}

    match = self::NEVRA_REGEX.match(line)
    if match
      self::NEVRA_FIELDS.zip(match.captures) { |f, v| hash[f] = v }
      hash[:provider] = self.name
      hash[:ensure] = "#{hash[:version]}-#{hash[:release]}"
      hash[:ensure].prepend("#{hash[:epoch]}:") if hash[:epoch] != '0'
    else
      Puppet.debug("Failed to match rpm line #{line}")
    end

    return hash
  end

  # @param line [String] multiple lines of rpm package query information
  # @return list of [Hash] of NEVRA_FIELDS strings parsed from package info
  # or an empty list if we failed to parse
  # @api private
  def self.nevra_to_multiversion_hash(multiline)
    list = []
    multiversion_hash = {}
    multiline.each_line do |line|
      hash = self.nevra_to_hash(line)
      next if hash.empty?

      if multiversion_hash.empty?
        multiversion_hash = hash.dup
        next
      end

      if multiversion_hash[:name] != hash[:name]
        list << multiversion_hash
        multiversion_hash = hash.dup
        next
      end

      unless multiversion_hash[:ensure].include?(hash[:ensure])
        multiversion_hash[:ensure].concat("#{self::MULTIVERSION_SEPARATOR}#{hash[:ensure]}")
      end
    end
    list << multiversion_hash if multiversion_hash
    if list.size == 1
      return list[0]
    end

    return list
  end
end
