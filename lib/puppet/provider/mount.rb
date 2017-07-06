require 'puppet'

# A module just to store the mount/unmount methods.  Individual providers
# still need to add the mount commands manually.
module Puppet::Provider::Mount
  # This only works when the mount point is synced to the fstab.
  def mount
    args = []

    # In general we do not have to pass mountoptions because we always
    # flush /etc/fstab before attempting to mount. But old code suggests
    # that MacOS always needs the mount options to be explicitly passed to
    # the mount command
    if Facter.value(:kernel) == 'Darwin'
      args << "-o" << self.options if self.options and self.options != :absent
    end
    args << resource[:name]

    mountcmd(*args)
    case get(:ensure)
    when :absent; set(:ensure => :ghost)
    when :unmounted; set(:ensure => :mounted)
    end
  end

  def remount
    info "Remounting"
    if resource[:remounts] == :true
      mountcmd "-o", "remount", resource[:name]
    elsif ["FreeBSD", "DragonFly", "OpenBSD"].include?(Facter.value(:operatingsystem))
      if self.options && !self.options.empty?
        options = self.options + ",update"
      else
        options = "update"
      end
      mountcmd "-o", options, resource[:name]
    else
      unmount
      mount
    end
  end

  # This only works when the mount point is synced to the fstab.
  def unmount
    umount(resource[:name])

    # Update property hash for future queries (e.g. refresh is called)
    case get(:ensure)
    when :mounted; set(:ensure => :unmounted)
    when :ghost; set(:ensure => :absent)
    end
  end

  # Is the mount currently mounted?
  def mounted?
    [:mounted, :ghost].include?(get(:ensure))
  end
end
