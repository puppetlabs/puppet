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
    #TRANSLATORS refers to remounting a file system
    info _("Remounting")
    os = Facter.value(:operatingsystem)
    supports_remounts = (resource[:remounts] == :true)
    if supports_remounts && os == 'AIX'
      remount_with_option("remount")
    elsif os.match(/^(FreeBSD|DragonFly|OpenBSD)$/)
      remount_with_option("update")
    elsif supports_remounts
      mountcmd "-o", "remount", resource[:name]
    else
      unmount
      mount
    end
  end

  # Remount by appending the supplied param "option" to any existing explicitly
  # defined options. If resource has no explicitly defined options, will mount
  # with only "option".
  # @param [String] option A remount option to use or append with existing options
  #
  def remount_with_option(option)
    if using_explicit_options?
      options = self.options + "," + option
    else
      options = option
    end
    mountcmd "-o", options, resource[:name]
  end

  def using_explicit_options?
    !self.options.nil? && !self.options.empty?
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
