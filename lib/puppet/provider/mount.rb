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
