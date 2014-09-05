require 'puppet/provider/package'
require 'set'
require 'uri'

Puppet::Type.type(:package).provide :pacman, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (pacman) used in Archlinux."

  commands :pacman => "/usr/bin/pacman"
  # Yaourt is a common AUR helper which, if installed, we can use to query the AUR
  commands :yaourt => "/usr/bin/yaourt" if Puppet::FileSystem.exist? '/usr/bin/yaourt'

  confine     :operatingsystem => :archlinux
  defaultfor  :operatingsystem => :archlinux
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :upgradeable
  has_feature :virtual_packages

  # Fetch the list of packages and package groups that are currently installed on the system.
  # Only package groups that are fully installed are included. If a group adds packages over time, it will not
  # be considered as fully installed any more, and we would install the new packages on the next run.
  # If a group removes packages over time, nothing will happen. This is intended.
  def self.instances
    instances = []
    installed_packages = get_installed_packages
    installed_packages.sort_by { |k, v| k }.each do |(pkgname, pkgver)|
      hash = {
        :name => pkgname,
        :ensure => pkgver,
        :provider => self.name,
      }
      instances << new(hash)
    end

    # Get list of groupnames that have at least one package installed and add them to instances
    begin
      execpipe([command(:pacman), "-Qg"]) do |process|
        # pacman -Qg output is 'groupname packagename'
        # Groups need to be deduplicated
        group_names = Set[]

        process.each_line do |line|
          group_names.add(line.split[0])
        end

        group_names.each do |group|
          group_version, fully_installed = get_virtual_group_version(group, installed_packages)
          if fully_installed
            instances << new({ :name => group, :ensure => group_version, :provider => self.name })
          end
        end
      end
    rescue Puppet::ExecutionFailure
      fail("Error getting groupnames of installed packages")
    end

    instances
  end

  # returns a hash pkgname => pkgversion of installed packages
  def self.get_installed_packages
    begin
      packages = {}
      execpipe([command(:pacman), "-Q"]) do |process|
        # pacman -Q output is 'packagename version-rel'
        regex = %r{^(\S+)\s(\S+)}
        process.each_line do |line|
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

  # Generates a virtual version for a group - a line in the format "<pkgname> <pkgversion>" per package.
  # For missing packages the pkgversion is skipped. This should trigger a group install when this string is compared
  # to the output of latest (which will have package versions given for all packages).
  # Needs to be passed a groupname and a hash pkgname => pkgversion of installed packages.
  # Returns a tuple of the generated version and a boolean indicating if the group is fully installed.
  def self.get_virtual_group_version group, package_versions
    begin
      fully_installed = true
      group_version = "\n" # the leading newline is just to make Puppet's output look nicer
      group_pkgs = []
      execpipe([command(:pacman), "-Sg", group]) do |process|
        process.each_line do |line|
          group_pkg = line.split[1]
          # if a package is missing, the group should be considered to be present
          fully_installed = false unless package_versions[group_pkg]
          group_pkgs << group_pkg
        end
      end
      # sort packages by name
      group_pkgs.sort.each do |group_pkg|
        group_version += "#{group_pkg} #{package_versions[group_pkg]}\n"
      end
      [group_version, fully_installed]
    rescue Puppet::ExecutionFailure
      fail("Error while getting virtual group version for '#{@resource[:name]}'")
    end
  end

  # If yaourt is installed, we can make use of it
  def self.yaourt?
    @yaourt ||= Puppet::FileSystem.exist?('/usr/bin/yaourt')
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
      fail("Could not find package '#{self.name}'")
    end
  end

  # Checks if a given name is a group
  def group? name
    begin
      !pacman("-Sg", @resource[:name]).empty?
    rescue Puppet::ExecutionFailure
      fail("Error while determining if '#{@resource[:name]}' is a group")
    end
  end
  private :group?

  def install_options
    join_options(@resource[:install_options])
  end
  private :install_options

  def install_from_repo
    if group?(@resource[:name]) && !@resource.allow_virtual?
      fail("Refusing to install package group '#{@resource[:name]}', because allow_virtual is false.")
    end
    if self.class.yaourt?
      cmd = %w{--noconfirm --needed}
      cmd += install_options if @resource[:install_options]
      cmd << "-S" << @resource[:name]
      yaourt *cmd
    else
      cmd = %w{--noconfirm  --needed --noprogressbar}
      cmd += install_options if @resource[:install_options]
      cmd << "-Sy" << @resource[:name]
      pacman *cmd
    end
  end
  private :install_from_repo

  def install_from_file
    source = @resource[:source]
    begin
      source_uri = URI.parse source
    rescue => detail
      fail("Invalid source '#{source}': #{detail}")
    end

    source = case source_uri.scheme
    when nil then source
    when /https?/i then source
    when /ftp/i then source
    when /file/i then source_uri.path
    when /puppet/i
      fail("puppet:// URL is not supported by pacman")
    else
      fail("Source '#{source}' is not supported by pacman")
    end
    pacman "--noconfirm", "--noprogressbar", "-Sy"
    pacman "--noconfirm", "--noprogressbar", "-U", source
  end
  private :install_from_file

  # Because Archlinux is a rolling release based distro, installing a package
  # should always result in the newest release.
  def update
    # Install in pacman can be used for update, too
    self.install
  end

  def uninstall_options
    join_options(@resource[:uninstall_options])
  end
  private :uninstall_options

  # Removes a package from the system.
  def uninstall
    if group?(@resource[:name]) && !@resource.allow_virtual?
      fail("Refusing to uninstall package group '#{@resource[:name]}', because allow_virtual is false.")
    end
    cmd = %w{--noconfirm --noprogressbar}
    cmd += uninstall_options if @resource[:uninstall_options]
    cmd << "-R" << @resource[:name]
    pacman *cmd
  end

  # We rescue the main check from Pacman with a check on the AUR using yaourt, if installed
  def latest
    pacman "-Sy"
    # If target is a group, construct the virtual group version
    if group?(@resource[:name])
      output = pacman("-Sp", "--print-format", "%n %v", @resource[:name])
      # sort packages by name and add leading line break as in get_virtual_group_version
      return "\n" + output.lines.sort.join
    end
    pacman_check = true   # Query the main repos first
    begin
      if pacman_check
        output = pacman "-Sp", "--print-format", "%v", @resource[:name]
        return output.chomp
      else
        output = yaourt "-Qma", @resource[:name]
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

  # Querys an installed package for information
  def query
    installed_packages = self.class.get_installed_packages

    # generate the virtual group version of the target is a group
    if group?(@resource[:name])
      unless @resource.allow_virtual?
        warning("#{@resource[:name]} is a group, but allow_virtual is false.")
        return nil
      end
      group_version, fully_installed = self.class.get_virtual_group_version(@resource[:name], installed_packages)
      if group_version && fully_installed
        return { :ensure => group_version }
      else
        return {
          :ensure => :absent,
          :status => 'missing',
          :name => @resource[:name],
          :error => 'ok',
        }
      end
    end

    # return the version if the package is installed
    if pkgversion = installed_packages[@resource[:name]]
      return { :ensure => pkgversion }
    # report package missing if it is not installed
    else
      return {
        :ensure => :absent,
        :status => 'missing',
        :name => @resource[:name],
        :error => 'ok',
      }
    end
  end

end
