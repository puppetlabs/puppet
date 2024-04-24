# frozen_string_literal: true

require_relative "../../../puppet/provider/package"

Puppet::Type.type(:package).provide :xbps, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (xbps) used in VoidLinux.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to xbps-install.
  These options should be specified as an array where each element is either a string or a hash."

  commands :xbps_install => "/usr/bin/xbps-install"
  commands :xbps_remove => "/usr/bin/xbps-remove"
  commands :xbps_query => "/usr/bin/xbps-query"
  commands :xbps_pkgdb => "/usr/bin/xbps-pkgdb"

  confine 'os.name' => :void
  defaultfor 'os.name' => :void
  has_feature :install_options, :uninstall_options, :upgradeable, :holdable, :virtual_packages

  def self.defaultto_allow_virtual
    false
  end

  # Fetch the list of packages that are currently installed on the system.
  def self.instances
    packages = []
    execpipe([command(:xbps_query), "-l"]) do |pipe|
      # xbps-query -l output is 'ii package-name-version     desc'
      regex = /^\S+\s(\S+)-(\S+)\s+\S+/
      pipe.each_line do |line|
        match = regex.match(line.chomp)
        if match
          packages << new({ name: match.captures[0], ensure: match.captures[1], provider: name })
        else
          warning(_("Failed to match line '%{line}'") % { line: line })
        end
      end
    end

    packages
  rescue Puppet::ExecutionFailure
    fail(_("Error getting installed packages"))
  end

  # Install a package quietly (without confirmation or progress bar) using 'xbps-install'.
  def install
    resource_name = @resource[:name]
    resource_source = @resource[:source]

    cmd = %w[-S -y]
    cmd += install_options if @resource[:install_options]
    cmd << "--repository=#{resource_source}" if resource_source
    cmd << resource_name

    unhold if properties[:mark] == :hold
    begin
      xbps_install(*cmd)
    ensure
      hold if @resource[:mark] == :hold
    end
  end

  # Because Voidlinux is a rolling release based distro, installing a package
  # should always result in the newest release.
  def update
    install
  end

  # Removes a package from the system.
  def uninstall
    resource_name = @resource[:name]

    cmd = %w[-R -y]
    cmd += uninstall_options if @resource[:uninstall_options]
    cmd << resource_name

    xbps_remove(*cmd)
  end

  # The latest version of a given package
  def latest
    query&.[] :ensure
  end

  # Queries information for a package
  def query
    resource_name = @resource[:name]
    installed_packages = self.class.instances

    installed_packages.each do |pkg|
      return pkg.properties if @resource[:name].casecmp(pkg.name).zero?
    end

    return nil unless @resource.allow_virtual?

    # Search for virtual package
    output = xbps_query("-Rs", resource_name).chomp

    # xbps-query -Rs output is '[*] package-name-version     description'
    regex = /^\[\*\]+\s(\S+)-(\S+)\s+\S+/
    match = regex.match(output)

    return nil unless match

    { name: match.captures[0], ensure: match.captures[1], provider: self.class.name }
  end

  # Puts a package on hold, so it doesn't update by itself on system update
  def hold
    xbps_pkgdb("-m", "hold", @resource[:name])
  end

  # Puts a package out of hold
  def unhold
    xbps_pkgdb("-m", "unhold", @resource[:name])
  end

  private

  def install_options
    join_options(@resource[:install_options])
  end

  def uninstall_options
    join_options(@resource[:uninstall_options])
  end
end
