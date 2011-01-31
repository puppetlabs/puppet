#  Created by Luke Kanies on 2006-11-12.
#  Copyright (c) 2006. All rights reserved.

require 'puppet'

# A module just to store the mount/unmount methods.  Individual providers
# still need to add the mount commands manually.
module Puppet::Provider::Mount
  # This only works when the mount point is synced to the fstab.
  def mount
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

  # Is the mount currently mounted?
  def mounted?
    platform = Facter.value("operatingsystem")
    name = resource[:name]
    mounts = mountcmd.split("\n").find do |line|
      case platform
      when "Darwin"
        line =~ / on #{name} / or line =~ %r{ on /private/var/automount#{name}}
      when "Solaris", "HP-UX"
        line =~ /^#{name} on /
      when "AIX"
        line =~ /^[^\s]*\s+[^\s]+\s+#{name}\s/
      else
        line =~ / on #{name} /
      end
    end
  end
end
