#  Created by Luke Kanies on 2006-11-12.
#  Copyright (c) 2006. All rights reserved.

require 'puppet'

# A module just to store the mount/unmount methods.  Individual providers
# still need to add the mount commands manually.
module Puppet::Provider::Mount
  def mount
    # Make sure the fstab file & entry exists
    create

    if correctly_mounted?
      # Nothing to do!
    else
      if anything_mounted?
        unmount

        # We attempt to create the mount point here, because unmounting
        # certain file systems/devices can cause the mount point to be
        # deleted
        ::FileUtils.mkdir_p(resource[:name])
      end

      mount!
    end
  end

  # This only works when the mount point is synced to the fstab.
  def mount!
    # Manually pass the mount options in, since some OSes *cough*OS X*cough* don't
    # read from /etc/fstab but still want to use this type.
    args = []
    args << "-o" << self.options if self.options and self.options != :absent
    args << resource[:name]

    flush if respond_to?(:flush)
    mountcmd(*args)
  end

  def remount
    info "Remounting"
    if resource[:remounts] == :true
      mountcmd "-o", "remount", resource[:name]
    else
      unmount
      mount
    end
  end

  # This only works when the mount point is synced to the fstab.
  def unmount
    umount resource[:name]
  end

  # Is anything currently mounted at this point?
  def anything_mounted?
    platform = Facter.value("operatingsystem")
    name = resource[:name]
    mounts = mountcmd.split("\n").find do |line|
      case platform
      when "Darwin"
        line =~ / on #{name} / or line =~ %r{ on /private/var/automount#{name}}
      when "Solaris", "HP-UX"
        # Yes, Solaris does list mounts as "mount_point on device"
        line =~ /^#{name} on /
      when "AIX"
        line.split(/\s+/)[2] == name
      else
        line =~ / on #{name} /
      end
    end
  end

  # Is the desired thing mounted at this point?
  def correctly_mounted?
    platform = Facter.value("operatingsystem")
    name = resource[:name]
    device = resource[:device]
    mounts = mountcmd.split("\n").find do |line|
      case platform
      when "Darwin"
        line =~ /^#{device} on #{name} / or line =~ %r{^#{device} on /private/var/automount#{name}}
      when "Solaris", "HP-UX"
        # Yes, Solaris does list mounts as "mount_point on device"
        line =~ /^#{name} on #{device}/
      when "AIX"
        line.split(/\s+/)[2] == name &&
          line.split(/\s+/)[1] == device
      else
        line =~ /^#{device} on #{name} /
      end
    end
  end
end
