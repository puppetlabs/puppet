require 'puppet/provider/parsedfile'

fstab = nil
case Facter.value(:operatingsystem)
when "Solaris": fstab = "/etc/vfstab"
else
    fstab = "/etc/fstab"
end

Puppet::Type.type(:mount).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => fstab,
    :filetype => :flat
) do

    commands :mountcmd => "mount", :umount => "umount", :df => "df"

    @platform = Facter["operatingsystem"].value
    case @platform
    when "Solaris":
        @fields = [:device, :blockdevice, :name, :fstype, :pass, :atboot,
               :options]
    else
        @fields = [:device, :name, :fstype, :options, :dump, :pass]
        @fielddefaults = [ nil ] * 4 + [ "0", "2" ]
    end

    text_line :comment, :match => /^\s*#/
    text_line :blank, :match => /^\s*$/

    record_line self.name, :fields => @fields, :separator => /\s+/, :joiner => "\t"

    # This only works when the mount point is synced to the fstab.
    def mount
        mountcmd @model[:name]
    end

    # This only works when the mount point is synced to the fstab.
    def unmount
        umount @model[:name]
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
                fs == "/private/var/automount" + @model[:name] or
                    fs == @model[:name]
            else
                fs == @model[:name]
            end
        end
    end
end

# $Id$
