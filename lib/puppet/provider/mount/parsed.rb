require 'puppet/provider/parsedfile'
require 'puppet/provider/mount'

fstab = nil
case Facter.value(:operatingsystem)
when "Solaris"; fstab = "/etc/vfstab"
else
  fstab = "/etc/fstab"
end


Puppet::Type.type(:mount).provide(:parsed,:parent => Puppet::Provider::ParsedFile,:default_target => fstab,:filetype => :flat) do
  include Puppet::Provider::Mount
  #confine :exists => fstab

  commands :mountcmd => "mount", :umount => "umount"

  case Facter["operatingsystem"]
  when "Solaris"
    @fields = [:device, :blockdevice, :name, :fstype, :pass, :atboot, :options]
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

  # Every entry in fstab is :unmounted until we can prove different
  def self.prefetch_hook(target_records)
    target_records.collect do |record|
      record[:ensure] = :unmounted if record[:record_type] == :parsed
      record
    end
  end

  def self.prefetch(resources = nil)
    # Get providers for all resources the user defined and that match
    # a record in /etc/fstab.
    super
    # We need to do two things now:
    # - Update ensure from :unmounted to :mounted if the resource is mounted
    # - Check for mounted devices that are not in fstab and
    #   set ensure to :ghost (if the user wants to add an entry
    #   to fstab we need to know if the device was mounted before)
    mountinstances.each do |hash|
      if mount = resources[hash[:name]]
        case mount.provider.get(:ensure)
        when :absent  # Mount not in fstab
          mount.provider.set(:ensure => :ghost)
        when :unmounted # Mount in fstab
          mount.provider.set(:ensure => :mounted)
        end
      end
    end
  end

  def self.mountinstances
    # XXX: Will not work for mount points that have spaces in path (does fstab support this anyways?)
    regex = case Facter.value(:operatingsystem)
      when "Darwin"
        / on (?:\/private\/var\/automount)?(\S*)/
      when "Solaris", "HP-UX"
        /^(\S*) on /
      else
        / on (\S*)/
    end
    instances = []
    mountcmd.split("\n").each do |line|
      if match = regex.match(line) and name = match.captures.first
        instances << {:name => name, :mounted => :yes} # Only :name is important here
      else
        raise Puppet::Error, "Could not understand line #{line} from mount output"
      end
    end
    instances
  end

end

