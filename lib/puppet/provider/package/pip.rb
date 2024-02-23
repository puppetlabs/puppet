# frozen_string_literal: true

# Puppet package provider for Python's `pip` package management frontend.
# <http://pip.pypa.io/>

require_relative '../../../puppet/util/package/version/pip'
require_relative '../../../puppet/util/package/version/range'
require_relative '../../../puppet/provider/package_targetable'

Puppet::Type.type(:package).provide :pip, :parent => ::Puppet::Provider::Package::Targetable do
  desc "Python packages via `pip`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip.
  These options should be specified as an array where each element is either a string or a hash."

  has_feature :installable, :uninstallable, :upgradeable, :versionable, :version_ranges, :install_options, :targetable

  PIP_VERSION       = Puppet::Util::Package::Version::Pip
  PIP_VERSION_RANGE = Puppet::Util::Package::Version::Range

  # Override the specificity method to return 1 if pip is not set as default provider
  def self.specificity
    match = default_match
    length = match ? match.length : 0

    return 1 if length == 0

    super
  end

  # Define the default provider package command name when the provider is targetable.
  # Required by Puppet::Provider::Package::Targetable::resource_or_provider_command
  def self.provider_command
    # Ensure pip can upgrade pip, which usually puts pip into a new path /usr/local/bin/pip (compared to /usr/bin/pip)
    self.cmd.map { |c| which(c) }.find { |c| c != nil }
  end

  def self.cmd
    if Puppet::Util::Platform.windows?
      ["pip.exe"]
    else
      ["pip", "pip-python", "pip2", "pip-2"]
    end
  end

  def self.pip_version(command)
    version = nil
    execpipe [quote(command), '--version'] do |process|
      process.collect do |line|
        md = line.strip.match(/^pip (\d+\.\d+\.?\d*).*$/)
        if md
          version = md[1]
          break
        end
      end
    end

    raise Puppet::Error, _("Cannot resolve pip version") unless version

    version
  end

  # Return an array of structured information about every installed package
  # that's managed by `pip` or an empty array if `pip` is not available.
  def self.instances(target_command = nil)
    if target_command
      command = target_command
      self.validate_command(command)
    else
      command = provider_command
    end

    packages = []
    return packages unless command

    command_options = ['freeze']
    command_version = self.pip_version(command)
    if compare_pip_versions(command_version, '8.1.0') >= 0
      command_options << '--all'
    end

    execpipe [quote(command), command_options] do |process|
      process.collect do |line|
        pkg = parse(line)
        next unless pkg

        pkg[:command] = command
        packages << new(pkg)
      end
    end

    # Pip can also upgrade pip, but it's not listed in freeze so need to special case it
    # Pip list would also show pip installed version, but "pip list" doesn't exist for older versions of pip (E.G v1.0)
    # Not needed when "pip freeze --all" is available.
    if compare_pip_versions(command_version, '8.1.0') == -1
      packages << new({ :ensure => command_version, :name => File.basename(command), :provider => name, :command => command })
    end

    packages
  end

  # Parse lines of output from `pip freeze`, which are structured as:
  # _package_==_version_ or _package_===_version_
  def self.parse(line)
    if line.chomp =~ /^([^=]+)===?([^=]+)$/
      { :ensure => $2, :name => $1, :provider => name }
    end
  end

  # Return structured information about a particular package or `nil`
  # if the package is not installed or `pip` itself is not available.
  def query
    command = resource_or_provider_command
    self.class.validate_command(command)

    self.class.instances(command).each do |pkg|
      return pkg.properties if @resource[:name].casecmp(pkg.name).zero?
    end
    return nil
  end

  # Return latest version available for current package
  def latest
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_version = self.class.pip_version(command)
    if self.class.compare_pip_versions(command_version, '1.5.4') == -1
      available_versions_with_old_pip.last
    else
      available_versions_with_new_pip(command_version).last
    end
  end

  def self.compare_pip_versions(x, y)
    begin
      Puppet::Util::Package::Version::Pip.compare(x, y)
    rescue PIP_VERSION::ValidationFailure => ex
      Puppet.debug("Cannot compare #{x} and #{y}. #{ex.message} Falling through default comparison mechanism.")
      Puppet::Util::Package.versioncmp(x, y)
    end
  end

  # Use pip CLI to look up versions from PyPI repositories,
  # honoring local pip config such as custom repositories.
  def available_versions
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_version = self.class.pip_version(command)
    if self.class.compare_pip_versions(command_version, '1.5.4') == -1
      available_versions_with_old_pip
    else
      available_versions_with_new_pip(command_version)
    end
  end

  def available_versions_with_new_pip(command_version)
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_and_options = [self.class.quote(command), 'install', "#{@resource[:name]}==versionplease"]
    extra_arg = list_extra_flags(command_version)
    command_and_options << extra_arg if extra_arg
    command_and_options << install_options if @resource[:install_options]
    execpipe command_and_options do |process|
      process.collect do |line|
        # PIP OUTPUT: Could not find a version that satisfies the requirement example==versionplease (from versions: 1.2.3, 4.5.6)
        next unless line =~ /from versions: (.+)\)/

        versionList = $1.split(', ').sort do |x, y|
          self.class.compare_pip_versions(x, y)
        end
        return versionList
      end
    end
    []
  end

  def available_versions_with_old_pip
    command = resource_or_provider_command
    self.class.validate_command(command)

    Dir.mktmpdir("puppet_pip") do |dir|
      command_and_options = [self.class.quote(command), 'install', "#{@resource[:name]}", '-d', "#{dir}", '-v']
      command_and_options << install_options if @resource[:install_options]
      execpipe command_and_options do |process|
        process.collect do |line|
          # PIP OUTPUT: Using version 0.10.1 (newest of versions: 1.2.3, 4.5.6)
          next unless line =~ /Using version .+? \(newest of versions: (.+?)\)/

          versionList = $1.split(', ').sort do |x, y|
            self.class.compare_pip_versions(x, y)
          end
          return versionList
        end
      end
      return []
    end
  end

  # Finds the most suitable version available in a given range
  def best_version(should_range)
    included_available_versions = []
    available_versions.each do |version|
      version = PIP_VERSION.parse(version)
      included_available_versions.push(version) if should_range.include?(version)
    end

    included_available_versions.sort!
    return included_available_versions.last unless included_available_versions.empty?

    Puppet.debug("No available version for package #{@resource[:name]} is included in range #{should_range}")
    should_range
  end

  def get_install_command_options
    should = @resource[:ensure]
    command_options = %w{install -q}
    command_options += install_options if @resource[:install_options]

    if @resource[:source]
      if should.is_a?(String)
        command_options << "#{@resource[:source]}@#{should}#egg=#{@resource[:name]}"
      else
        command_options << "#{@resource[:source]}#egg=#{@resource[:name]}"
      end

      return command_options
    end

    if should == :latest
      command_options << "--upgrade" << @resource[:name]

      return command_options
    end

    unless should.is_a?(String)
      command_options << @resource[:name]

      return command_options
    end

    begin
      should_range = PIP_VERSION_RANGE.parse(should, PIP_VERSION)
    rescue PIP_VERSION_RANGE::ValidationFailure, PIP_VERSION::ValidationFailure
      Puppet.debug("Cannot parse #{should} as a pip version range, falling through.")
      command_options << "#{@resource[:name]}==#{should}"

      return command_options
    end

    if should_range.is_a?(PIP_VERSION_RANGE::Eq)
      command_options << "#{@resource[:name]}==#{should}"

      return command_options
    end

    should = best_version(should_range)

    if should == should_range
      # when no suitable version for the given range was found, let pip handle
      if should.is_a?(PIP_VERSION_RANGE::MinMax)
        command_options << "#{@resource[:name]} #{should.split.join(',')}"
      else
        command_options << "#{@resource[:name]} #{should}"
      end
    else
      command_options << "#{@resource[:name]}==#{should}"
    end

    command_options
  end

  # Install a package.  The ensure parameter may specify installed,
  # latest, a version number, or, in conjunction with the source
  # parameter, an SCM revision.  In that case, the source parameter
  # gives the fully-qualified URL to the repository.
  def install
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_options = get_install_command_options
    execute([command, command_options])
  end

  # Uninstall a package. Uninstall won't work reliably on Debian/Ubuntu unless this issue gets fixed.
  # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=562544
  def uninstall
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_options = ["uninstall", "-y", "-q", @resource[:name]]

    execute([command, command_options])
  end

  def update
    install
  end

  def install_options
    join_options(@resource[:install_options])
  end

  def insync?(is)
    return false unless is && is != :absent

    begin
      should = @resource[:ensure]
      should_range = PIP_VERSION_RANGE.parse(should, PIP_VERSION)
    rescue PIP_VERSION_RANGE::ValidationFailure, PIP_VERSION::ValidationFailure
      Puppet.debug("Cannot parse #{should} as a pip version range")
      return false
    end

    begin
      is_version = PIP_VERSION.parse(is)
    rescue PIP_VERSION::ValidationFailure
      Puppet.debug("Cannot parse #{is} as a pip version")
      return false
    end

    should_range.include?(is_version)
  end

  # Quoting is required if the path to the pip command contains spaces.
  # Required for execpipe() but not execute(), as execute() already does this.
  def self.quote(path)
    if path.include?(" ")
      "\"#{path}\""
    else
      path
    end
  end

  private

  def list_extra_flags(command_version)
    klass = self.class
    if klass.compare_pip_versions(command_version, '20.2.4') == 1 &&
       klass.compare_pip_versions(command_version, '21.1') == -1
      '--use-deprecated=legacy-resolver'
    end
  end
end
