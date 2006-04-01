require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:mount, Puppet::Type::ParsedType) do

        ensurable do
            newvalue(:present) do
                @parent.create()
            end

            newvalue(:absent) do
                @parent.destroy()

                if @parent.mounted?
                    @parent.unmount
                end

                :mount_removed
            end

            newvalue(:mounted) do
                if @is == :absent
                    set_present
                end

                @parent.mount

                :mount_mounted
            end
        end

        newstate(:device) do
            desc "The device providing the mount.  This can be whatever
                device is supporting by the mount, including network
                devices or devices specified by UUID rather than device
                path, depending on the operating system."
        end

        # Solaris specifies two devices, not just one.
        newstate(:blockdevice) do
            desc "The the device to fsck.  This is state is only valid
                on Solaris, and in most cases will default to the correct
                value."

            # Default to the device but with "dsk" replaced with "rdsk".
            defaultto do
                if Facter["operatingsystem"].value == "Solaris"
                    device = @parent.value(:device)
                    if device =~ %r{/dsk/}
                        device.sub(%r{/dsk/}, "/rdsk/")
                    else
                        nil
                    end
                else
                    nil
                end
            end
        end

        newstate(:fstype) do
            desc "The mount type.  Valid values depend on the
                operating system."
        end

        newstate(:options) do
            desc "Mount options for the mounts, as they would
                appear in the fstab."
        end

        newstate(:pass) do
            desc "The pass in which the mount is checked."
        end

        newstate(:atboot) do
            desc "Whether to mount the mount at boot.  Not all platforms
                support this."
        end

        newstate(:dump) do
            desc "Whether to dump the mount.  Not all platforms
                support this."
        end

        newparam(:path) do
            desc "The mount path for the mount."

            isnamevar
        end

        @doc = "Manages mounted mounts, including putting mount
            information into the mount table."

        @instances = []

        case Facter["operatingsystem"].value
        when "Solaris":
            @path = "/etc/vfstab"
            @fields = [:device, :blockdevice, :path, :fstype, :pass, :atboot,
                :options]
        else
            @path = "/etc/fstab"
            @fields = [:device, :path, :fstype, :options, :dump, :pass]
        end

        @filetype = Puppet::FileType.filetype(:flat)

        # Parse a mount tab.
        #
        # This method also stores existing comments, and it stores all
        # mounts in order, mostly so that comments are retained in the
        # order they were written and in proximity to the same fses.
        def self.parse(text)
            count = 0
            hash = {}
            text.chomp.split("\n").each { |line|
                case line
                when /^#/, /^\s*$/:
                    # add comments and blank lines to the list as they are
                    comment(line)
                else
                    values = line.split(/\s+/)
                    unless @fields.length == values.length
                        raise Puppet::Error, "Could not parse line %s" % line
                    end

                    @fields.zip(values).each do |field, value|
                        hash[field] = value
                    end

                    hash2obj(hash)

                    hash.clear
                    count += 1
                end
            }
        end

        # This only works when the mount point is synced to the fstab.
        def mount
            output = %x{mount #{self[:path]} 2>&1}

            unless $? == 0
                raise Puppet::Error, "Could not mount %s: %s" % [self[:path], output]
            end
        end

        # This only works when the mount point is synced to the fstab.
        def unmount
            output = %x{umount #{self[:path]}}

            unless $? == 0
                raise Puppet::Error, "Could not mount %s" % self[:path]
            end
        end

        # Is the mount currently mounted?
        def mounted?
            %x{df}.split("\n").find do |line|
                fs = line.split(/\s+/)[-1]
                fs == self[:path]
            end
        end

        # Convert the current object into an fstab-style string.
        def to_record
            self.class.fields.collect do |field|
                if value = self.value(field)
                    value
                else
                    if @states.include? field
                        self.warning @states[field].inspect
                    else
                        self.warning field.inspect
                    end
                    raise Puppet::Error,
                        "Could not retrieve value for %s" % field
                end
            end.join("\t")
        end
    end
end

# $Id$
