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
        if self.options and self.options != :absent
            args << "-o" << self.options
        end
        args << @resource[:name]

        mountcmd(*args)
    end

    def remount
        info "Remounting"
        if @resource[:remounts] == :true
            mountcmd "-o", "remount", @resource[:name]
        else
            unmount()
            mount()
        end
    end

    # This only works when the mount point is synced to the fstab.
    def unmount
        umount @resource[:name]
    end

    # Is the mount currently mounted?
    def mounted?
        platform = Facter["operatingsystem"].value
        df = [command(:df)]
        case Facter["operatingsystem"].value
        # Solaris's df prints in a very weird format
        when "Solaris": df << "-k"
        end
        execute(df).split("\n").find do |line|
            fs = line.split(/\s+/)[-1]
            if platform == "Darwin"
                fs == "/private/var/automount" + @resource[:name] or
                    fs == @resource[:name]
            else
                fs == @resource[:name]
            end
        end
    end
end

# $Id$
