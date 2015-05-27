require 'puppet/provider/package'
require 'set'
require 'uri'

Puppet::Type.type(:package).provide :pacman, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (pacman) used in Archlinux.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pacman.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  # If yaourt is installed, we can make use of it
  def self.yaourt?
    @yaourt ||= Puppet::FileSystem.exist?('/usr/bin/yaourt')
  end

  commands :pacman => "/usr/bin/pacman"
  # Yaourt is a common AUR helper which, if installed, we can use to query the AUR
  commands :yaourt => "/usr/bin/yaourt" if yaourt?

  confine     :operatingsystem => [:archlinux, :manjarolinux]
  defaultfor  :operatingsystem => [:archlinux, :manjarolinux]
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :upgradeable
  has_feature :virtual_packages

  # Checks if a given name is a group
  def self.group?(name)
    begin
      !pacman("-Sg", name).empty?
    rescue Puppet::ExecutionFailure
      # pacman returns an expected non-zero exit code when the name is not a group
      false
    end
  end

  # Install a package using 'pacman', or 'yaourt' if available.
  # Installs quietly, without confirmation or progressbar, updates package
  # list from servers defined in pacman.conf.
  def install
    if @resource[:source]
      install_from_file
    else
      install_from_repo
    end

    unless self.query
      fail("Could not find package '#{@resource[:name]}'")
    end
  end

  # Fetch the list of packages and package groups that are currently installed on the system.
  # Only package groups that are fully installed are included. If a group adds packages over time, it will not
  # be considered as fully installed any more, and we would install the new packages on the next run.
  # If a group removes packages over time, nothing will happen. This is intended.
  def self.instances
    instances = []

    # Get the installed packages
    installed_packages = get_installed_packages
    installed_packages.sort_by { |k, _| k }.each do |package, version|
      instances << new(to_resource_hash(package, version))
    end

    # Get the installed groups
    get_installed_groups(installed_packages).each do |group, version|
      instances << new(to_resource_hash(group, version))
    end

    instances
  end

  # returns a hash package => version of installed packages
  def self.get_installed_packages
    begin
      packages = {}
      execpipe([command(:pacman), "-Q"]) do |pipe|
        # pacman -Q output is 'packagename version-rel'
        regex = %r{^(\S+)\s(\S+)}
        pipe.each_line do |line|
          if match = regex.match(line)
            packages[match.captures[0]] = match.captures[1]
          else
            warning("Failed to match line '#{line}'")
          end
        end
      end
      packages
    rescue Puppet::ExecutionFailure
      fail("Error getting installed packages")
    end
  end

  # returns a hash of group => version of installed groups
  def self.get_installed_groups(installed_packages, filter = nil)
    groups = {}
    begin
      # Build a hash of group name => list of packages
      command = [command(:pacman), "-Sgg"]
      command << filter if filter
      execpipe(command) do |pipe|
        pipe.each_line do |line|
          name, package = line.split
          packages = (groups[name] ||= [])
          packages << package
        end
      end

      # Remove any group that doesn't have all its packages installed
      groups.delete_if do |_, packages|
        !packages.all? { |package| installed_packages[package] }
      end

      # Replace the list of packages with a version string consisting of packages that make up the group
      groups.each do |name, packages|
        groups[name] = packages.sort.map {|package| "#{package} #{installed_packages[package]}"}.join ', '
      end
    rescue Puppet::ExecutionFailure
      # pacman returns an expected non-zero exit code when the filter name is not a group
      raise unless filter
    end
    groups
  end

  # Because Archlinux is a rolling release based distro, installing a package
  # should always result in the newest release.
  def update
    # Install in pacman can be used for update, too
    self.install
  end

  # We rescue the main check from Pacman with a check on the AUR using yaourt, if installed
  def latest
    # Synchronize the database
    pacman "-Sy"

    resource_name = @resource[:name]

    # If target is a group, construct the group version
    return pacman("-Sp", "--print-format", "%n %v", resource_name).lines.map{ |line| line.chomp }.sort.join(', ') if self.class.group?(resource_name)

    # Start by querying with pacman first
    # If that fails, retry using yaourt against the AUR
    pacman_check = true
    begin
      if pacman_check
        output = pacman "-Sp", "--print-format", "%v", resource_name
        return output.chomp
      else
        output = yaourt "-Qma", resource_name
        output.split("\n").each do |line|
          return line.split[1].chomp if line =~ /^aur/
        end
      end
    rescue Puppet::ExecutionFailure
      if pacman_check and self.class.yaourt?
        pacman_check = false # now try the AUR
        retry
      else
        raise
      end
    end
  end

  # Querys information for a package or package group
  def query
    installed_packages = self.class.get_installed_packages
    resource_name = @resource[:name]

    # Check for the resource being a group
    version = self.class.get_installed_groups(installed_packages, resource_name)[resource_name]

    if version
      unless @resource.allow_virtual?
        warning("#{resource_name} is a group, but allow_virtual is false.")
        return nil
      end
    else
      version = installed_packages[resource_name]
    end

    # Return nil if no package or group found
    return nil unless version

    self.class.to_resource_hash(resource_name, version)
  end

  def self.to_resource_hash(name, version)
    {
      :name     => name,
      :ensure   => version,
      :provider => self.name
    }
  end

  # Removes a package from the system.
  def uninstall
    resource_name = @resource[:name]

    is_group = self.class.group?(resource_name)

    fail("Refusing to uninstall package group #{resource_name}, because allow_virtual is false.") if is_group && !@resource.allow_virtual?

    cmd = %w{--noconfirm --noprogressbar}
    cmd += uninstall_options if @resource[:uninstall_options]
    cmd << "-R"
    cmd << '-s' if is_group
    cmd << resource_name

    if self.class.yaourt?
      yaourt *cmd
    else
      pacman *cmd
    end
  end

  private

  def install_options
    join_options(@resource[:install_options])
  end

  def uninstall_options
    join_options(@resource[:uninstall_options])
  end

  def install_from_file
    source = @resource[:source]
    begin
      source_uri = URI.parse source
    rescue => detail
      self.fail Puppet::Error, "Invalid source '#{source}': #{detail}", detail
    end

    source = case source_uri.scheme
    when nil then source
    when /https?/i then source
    when /ftp/i then source
    when /file/i then source_uri.path
    when /puppet/i
      fail "puppet:// URL is not supported by pacman"
    else
      fail "Source #{source} is not supported by pacman"
    end
    pacman "--noconfirm", "--noprogressbar", "-Sy"
    pacman "--noconfirm", "--noprogressbar", "-U", source
  end

  def install_from_repo
    resource_name = @resource[:name]

    # Refuse to install if not allowing virtual packages and the resource is a group
    fail("Refusing to install package group #{resource_name}, because allow_virtual is false.") if self.class.group?(resource_name) && !@resource.allow_virtual?

    cmd = %w{--noconfirm --needed --noprogressbar}
    cmd += install_options if @resource[:install_options]
    cmd << "-Sy" << resource_name

    if self.class.yaourt?
      yaourt *cmd
    else
      pacman *cmd
    end
  end

end
