# Puppet package provider for Python's `pip` package management frontend.
# <http://pip.pypa.io/>

require 'puppet/provider/package_targetable'
require 'puppet/util/http_proxy'

Puppet::Type.type(:package).provide :pip, :parent => ::Puppet::Provider::Package::Targetable do

  desc "Python packages via `pip`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :installable, :uninstallable, :upgradeable, :versionable, :install_options, :targetable

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
    if Puppet.features.microsoft_windows?
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
    if Puppet::Util::Package.versioncmp(command_version, '8.1.0') >= 0
      command_options << '--all'
    end

    execpipe [quote(command), command_options] do |process|
      process.collect do |line|
        next unless pkg = parse(line)
        pkg[:command] = command
        packages << new(pkg)
      end
    end

    # Pip can also upgrade pip, but it's not listed in freeze so need to special case it
    # Pip list would also show pip installed version, but "pip list" doesn't exist for older versions of pip (E.G v1.0)
    # Not needed when "pip freeze --all" is available.
    if Puppet::Util::Package.versioncmp(command_version, '8.1.0') == -1
      packages << new({:ensure => command_version, :name => File.basename(command), :provider => name, :command => command})
    end

    packages
  end

  # Parse lines of output from `pip freeze`, which are structured as:
  # _package_==_version_

  def self.parse(line)
    if line.chomp =~ /^([^=]+)==([^=]+)$/
      {:ensure => $2, :name => $1, :provider => name}
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

  # Use pip CLI to look up versions from PyPI repositories,
  # honoring local pip config such as custom repositories.

  def latest
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_version = self.class.pip_version(command)
    if Puppet::Util::Package.versioncmp(command_version, '1.5.4') == -1
      latest_with_old_pip
    else
      latest_with_new_pip
    end
  end

  # Less resource-intensive approach for pip version 1.5.4 and newer.

  def latest_with_new_pip
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_and_options = [self.class.quote(command), 'install', "#{@resource[:name]}==versionplease"]
    command_and_options << install_options if @resource[:install_options]
    execpipe command_and_options do |process|
      process.collect do |line|
        # PIP OUTPUT: Could not find a version that satisfies the requirement example==versionplease (from versions: 1.2.3, 4.5.6)
        if line =~ /from versions: /
          textAfterLastMatch = $'.chomp(")\n")
          versionList = textAfterLastMatch.split(', ').sort do |x,y|
            Puppet::Util::Package.versioncmp(x, y)
          end
          return versionList.last
        end
      end
      return nil
    end
  end

  # More resource-intensive approach for pip version 1.5.3 and older.

  def latest_with_old_pip
    command = resource_or_provider_command
    self.class.validate_command(command)

    Dir.mktmpdir("puppet_pip") do |dir|
      command_and_options = [self.class.quote(command), 'install', "#{@resource[:name]}", '-d', "#{dir}", '-v']
      command_and_options << install_options if @resource[:install_options]
      execpipe command_and_options do |process|
        process.collect do |line|
          # PIP OUTPUT: Using version 0.10.1 (newest of versions: 1.2.3, 4.5.6)
          if line =~ /Using version (.+?) \(newest of versions/
            return $1
          end
        end
        return nil
      end
    end
  end

  # Install a package.  The ensure parameter may specify installed,
  # latest, a version number, or, in conjunction with the source
  # parameter, an SCM revision.  In that case, the source parameter
  # gives the fully-qualified URL to the repository.

  def install
    command = resource_or_provider_command
    self.class.validate_command(command)

    command_options = %w{install -q}
    command_options +=  install_options if @resource[:install_options]
    if @resource[:source]
      if String === @resource[:ensure]
        command_options << "#{@resource[:source]}@#{@resource[:ensure]}#egg=#{@resource[:name]}"
      else
        command_options << "#{@resource[:source]}#egg=#{@resource[:name]}"
      end
    else
      case @resource[:ensure]
      when String
        command_options << "#{@resource[:name]}==#{@resource[:ensure]}"
      when :latest
        command_options << "--upgrade" << @resource[:name]
      else
        command_options << @resource[:name]
      end
    end

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

  # Quoting is required if the path to the pip command contains spaces.
  # Required for execpipe() but not execute(), as execute() already does this.

  def self.quote(path)
    if path.include?(" ")
      "\"#{path}\""
    else
      path
    end
  end
end
