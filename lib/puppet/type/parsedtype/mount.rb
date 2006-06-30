require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:mount, Puppet::Type::ParsedType) do
        ensurable do
            desc "Create, remove, or mount a filesystem mount."

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

            def retrieve
                if @parent.mounted?
                    @is = :mounted
                else
                    val = super()
                    @is = val
                end
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

        def self.init
            @platform = Facter["operatingsystem"].value
            case @platform
            when "Solaris":
                    @path = "/etc/vfstab"
                @fields = [:device, :blockdevice, :path, :fstype, :pass, :atboot,
                           :options]
                @defaults = [ nil ] * @fields.size
            when "Darwin":
                    @filetype = Puppet::FileType.filetype(:netinfo)
                @filetype.format = "fstab"
                @path = "mounts"
                @fields = [:device, :path, :fstype, :options, :dump, :pass]
                @defaults = [ nil ] * @fields.size

                # How to map the dumped table to what we want
                @fieldnames = {
                    "name" => :device,
                    "dir" => :path,
                    "dump_freq" => :dump,
                    "passno" => :pass,
                    "vfstype" => :fstype,
                    "opts" => :options
                }
            else
                @path = "/etc/fstab"
                @fields = [:device, :path, :fstype, :options, :dump, :pass]
                @defaults = [ nil ] * 4 + [ "0" ] * 2
            end

            # Allow Darwin to override the default filetype
            unless defined? @filetype
                @filetype = Puppet::FileType.filetype(:flat)
            end
        end

        init

        def self.clear
            init
            super
        end

        # Parse a mount tab.
        #
        # This method also stores existing comments, and it stores all
        # mounts in order, mostly so that comments are retained in the
        # order they were written and in proximity to the same fses.
        def self.parse(text)
            # provide a single exception for darwin & netinfo
            if @filetype == Puppet::FileType.filetype(:netinfo)
                parseninfo(text)
                return 
            end
            count = 0
            hash = {}
            text.chomp.split("\n").each { |line|
                case line
                when /^#/, /^\s*$/:
                    # add comments and blank lines to the list as they are
                    comment(line)
                else
                    values = line.split(/\s+/)
                    if @fields.length < values.length
                        raise Puppet::Error, "Could not parse line %s" % line
                    end

                    values = @defaults.zip(values).collect { |d, v| v || d }
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

        # Parse a netinfo table.
        def self.parseninfo(text)
            array = @fileobj.to_array(text)

            hash = {}
            array.each do |record|
                @fieldnames.each do |name, field|
                    if value = record[name]
                        if field == :options
                            hash[field] = value.join(",")
                        else
                            hash[field] = value[0]
                        end
                    else
                        raise ArgumentError, "Field %s was not provided" % [name]
                    end
                end


                hash2obj(hash)
                hash.clear
            end
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
            platform = Facter["operatingsystem"].value
            df = "df"
            case Facter["operatingsystem"].value
            # Solaris's df prints in a very weird format
            when "Solaris": df = "df -k"
            end
            %x{#{df}}.split("\n").find do |line|
                fs = line.split(/\s+/)[-1]
                if platform == "Darwin"
                    fs == "/private/var/automount" + self[:path] or
                        fs == self[:path]
                else
                    fs == self[:path]
                end
            end
        end

        # Convert the current object into an fstab-style string.
        def to_record
            self.class.fields.collect do |field|
                if value = self.value(field)
                    value
                else
                    raise Puppet::Error,
                        "Could not retrieve value for %s" % field
                end
            end.join("\t")
        end
    end
end

# $Id$
