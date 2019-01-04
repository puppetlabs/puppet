# Puppet package provider for Python's `pip` package management frontend.
# <http://pip.pypa.io/>

require 'puppet/provider/package'
require 'puppet/util/http_proxy'

Puppet::Type.type(:package).provide :pip,
  :parent => ::Puppet::Provider::Package do

  desc "Python packages via `pip`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :installable, :uninstallable, :upgradeable, :versionable, :install_options, :targetable

  def self.cmd
    if Puppet::Util::Platform.windows?
      ["pip.exe"]
    else
      ["pip", "pip-python"]
    end
  end

  def self.default_pip_cmd
    self.cmd.map { |c| which(c) }.find { |c| c != nil }
  end

  # Return an array of structured information about every installed package
  # that's managed by `pip` or an empty array if `pip` is not available.
  def self.instances(cmd = nil)
    cmd = command_or_default_package_command(cmd)
    packages = []
    return packages unless cmd

    command = [cmd, 'freeze']
    command_version = self.pip_version(cmd)
    if Puppet::Util::Package.versioncmp(command_version, '8.1.0') >= 0
      command << '--all'
    end

    execpipe command do |process|
      process.collect do |line|
        next unless pkg = parse(line)
        pkg[:command] = cmd
        packages << new(pkg)
      end
    end

    # Pip can also upgrade pip, but it's not listed in freeze so need to special case it
    # Pip list would also show pip installed version, but "pip list" doesn't exist for older versions of pip (E.G v1.0)
    # Not needed when "pip freeze --all" is available
    if Puppet::Util::Package.versioncmp(command_version, '8.1.0') == -1 && version = command_version
      packages << new({:ensure => version, :name => File.basename(cmd), :provider => name, :command => cmd})
    end

    packages
  end

  # Determine the package command of this targetable package provider.
  #
  # cmd: the full path to the target package command.
  def self.command_or_default_package_command(cmd)
    if cmd
      validate_package_command(cmd)
      cmd
    else
      default_pip_cmd
    end
  end

  # Determine the package command of this targetable package resource.
  # Redefined from the parent class, as this class implements default_pip_cmd and lazy_pip.
  def resource_or_default_package_command
    if resource[:command] && resource[:command] != :default
      self.class.validate_package_command(resource[:command])
      resource[:command]
    else
      self.class.default_pip_cmd
    end
  end

  # Parse lines of output from `pip freeze`, which are structured as:
  #   _package_==_version_
  def self.parse(line)
    if line.chomp =~ /^([^=]+)==([^=]+)$/
      {:ensure => $2, :name => $1, :provider => name}
    else
      nil
    end
  end

  def self.pip_version(cmd)
    return nil unless cmd
    execpipe [cmd, '--version'] do |process|
      process.collect do |line|
        return line.strip.match(/^pip (\d+\.\d+\.?\d*).*$/)[1]
      end
    end
  end

  # Return structured information about a particular package
  # or `nil` if it is not installed or `pip` itself is not available.
  def query
    self.class.instances(resource_or_default_package_command).each do |provider_pip|
      return provider_pip.properties if @resource[:name].downcase == provider_pip.name.downcase
    end
    return nil
  end

  # Use pip CLI to look up versions from PyPI repositories,
  # honoring local pip config such as custom repositories.
  def latest
    command_version = self.pip_version(resource_or_default_package_command)
    if Puppet::Util::Package.versioncmp(command_version, '1.5.4') == -1
      latest_with_old_pip
    else
      latest_with_new_pip
    end
  end

  # Install a package.
  # The ensure parameter may specify installed, latest, a version number, or,
  # in conjunction with the source parameter, an SCM revision.
  # In that case, the source parameter gives the fully-qualified URL to the repository.
  def install
    args = %w{install -q}
    args +=  install_options if @resource[:install_options]
    if @resource[:source]
      if String === @resource[:ensure]
        args << "#{@resource[:source]}@#{@resource[:ensure]}#egg=#{
          @resource[:name]}"
      else
        args << "#{@resource[:source]}#egg=#{@resource[:name]}"
      end
    else
      case @resource[:ensure]
      when String
        args << "#{@resource[:name]}==#{@resource[:ensure]}"
      when :latest
        args << "--upgrade" << @resource[:name]
      else
        args << @resource[:name]
      end
    end

    lazy_pip(*args)
  end

  # Uninstall a package.
  # Uninstall won't work reliably on Debian/Ubuntu unless this issue gets fixed:
  # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=562544
  def uninstall
    lazy_pip("uninstall", "-y", "-q", @resource[:name])
  end

  def update
    install
  end

  def install_options
    join_options(@resource[:install_options])
  end

  def latest_with_new_pip
    # Less resource intensive approach for pip version 1.5.4 and above.
    execpipe [resource_or_default_package_command, "install", "#{@resource[:name]}==versionplease"] do |process|
      process.collect do |line|
        # PIP OUTPUT: Could not find a version that satisfies the requirement Django==versionplease (from versions: 1.1.3, 1.8rc1)
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

  def latest_with_old_pip
    Dir.mktmpdir("puppet_pip") do |dir|
      execpipe [resource_or_default_package_command, "install", "#{@resource[:name]}", "-d", "#{dir}", "-v"] do |process|
        process.collect do |line|
          # PIP OUTPUT: Using version 0.10.1 (newest of versions: 0.10.1, 0.10, 0.9, 0.8.1, 0.8, 0.7.2, 0.7.1, 0.7, 0.6.1, 0.6, 0.5.2, 0.5.1, 0.5, 0.4, 0.3.1, 0.3, 0.2, 0.1)
          if line =~ /Using version (.+?) \(newest of versions/
            return $1
          end
        end
        return nil
      end
    end
  end

  # Execute a `pip` command.
  # If Puppet doesn't yet know how to do so, try to teach it and if even that fails, raise the error.
  private
  def lazy_pip(*args)
    pip(*args)
  rescue NoMethodError
    # Ensure pip can upgrade pip, which usually puts pip into a new path /usr/local/bin/pip (compared to /usr/bin/pip)
    # The path to pip needs to be looked up again in the subsequent request.
    # Using the preferred approach as noted in provider.rb ensures this (copied below for reference)
    #
    # @note From provider.rb; It is preferred if the commands are not entered with absolute paths as this allows puppet
    # to search for them using the PATH variable.
    command = resource_or_default_package_command
    if command
      self.class.commands :pip => command
      pip(*args)
    else
      raise Puppet::Error, _('pip package command not specified or does not exist')
    end
  end
end
