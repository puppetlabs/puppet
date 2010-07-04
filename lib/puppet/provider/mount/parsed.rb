require 'puppet/provider/parsedfile'
require 'puppet/provider/mount'

fstab = nil
case Facter.value(:operatingsystem)
when "Solaris"; fstab = "/etc/vfstab"
else
    fstab = "/etc/fstab"
end

Puppet::Type.type(:mount).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => fstab,
    :filetype => :flat
) do
    include Puppet::Provider::Mount
    #confine :exists => fstab

    commands :mountcmd => "mount", :umount => "umount"

    @platform = Facter["operatingsystem"].value
    case @platform
    when "Solaris"
        @fields = [:device, :blockdevice, :name, :fstype, :pass, :atboot,
               :options]
    else
        @fields = [:device, :name, :fstype, :options, :dump, :pass]
        @fielddefaults = [ nil ] * 4 + [ "0", "2" ]
    end

    text_line :comment, :match => /^\s*#/
    text_line :blank, :match => /^\s*$/

    optional_fields  = @fields - [:device, :name, :blockdevice]
    mandatory_fields = @fields - optional_fields

    # fstab will ignore lines that have fewer than the mandatory number of columns,
    # so we should, too.
    field_pattern = '(\s*(?>\S+))'
    text_line :incomplete, :match => /^(?!#{field_pattern}{#{mandatory_fields.length}})/

    record_line self.name, :fields => @fields, :separator => /\s+/, :joiner => "\t", :optional => optional_fields

end

