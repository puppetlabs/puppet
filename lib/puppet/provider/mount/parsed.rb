require 'puppet/provider/parsedfile'

Puppet::Type.type(:mount).provide :parsed, :parent => Puppet::Provider::ParsedFile do
    @filetype = Puppet::FileType.filetype(:flat)

    commands :mount => "mount", :umount => "umount", :df => "df"

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
            @defaults = [ nil ] * 4 + [ "0", "2" ]
        end

        # Allow Darwin to override the default filetype
        unless defined? @filetype
            @filetype = Puppet::FileType.filetype(:flat)
        end
    end

    init

    confine :exists => @path

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
            return parseninfo(text)
        end
        count = 0

        instances = []
        text.chomp.split("\n").each { |line|
            hash = {}
            case line
            when /^#/, /^\s*$/:
                # add comments and blank lines to the list as they are
                instances << line
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

                instances << hash
                count += 1
            end
        }

        return instances
    end

    # Parse a netinfo table.
    def self.parseninfo(text)
        array = @fileobj.to_array(text)

        instances = []
        array.each do |record|
            hash = {}
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

            instances << hash
        end

        return instances
    end

    # Convert the current object into an fstab-style string.
    def self.to_record(hash)
        self.fields.collect do |field|
            if value = hash[field]
                value
            else
                raise Puppet::Error,
                    "Could not retrieve value for %s" % field
            end
        end.join("\t")
    end

    # This only works when the mount point is synced to the fstab.
    def mount
        output = %x{#{command(:mount)} #{@model[:path]} 2>&1}

        unless $? == 0
            raise Puppet::Error, "Could not mount %s: %s" % [@model[:path], output]
        end
    end

    # This only works when the mount point is synced to the fstab.
    def unmount
        output = %x{#{command(:umount)} #{@model[:path]}}

        unless $? == 0
            raise Puppet::Error, "Could not unmount %s" % @model[:path]
        end
    end

    # Is the mount currently mounted?
    def mounted?
        platform = Facter["operatingsystem"].value
        df = command(:df)
        case Facter["operatingsystem"].value
        # Solaris's df prints in a very weird format
        when "Solaris": df = "#{command(:df)} -k"
        end
        %x{#{df}}.split("\n").find do |line|
            fs = line.split(/\s+/)[-1]
            if platform == "Darwin"
                fs == "/private/var/automount" + @model[:path] or
                    fs == @model[:path]
            else
                fs == @model[:path]
            end
        end
    end
end

# $Id$
