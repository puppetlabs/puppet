require 'puppet/provider/parsedfile'
require 'puppet/provider/mount'

fstab = nil
case Facter.value(:osfamily)
when "Solaris"; fstab = "/etc/vfstab"
when "AIX"; fstab = "/etc/filesystems"
else
  fstab = "/etc/fstab"
end

Puppet::Type.type(:mount).provide(
  :parsed,
  :parent => Puppet::Provider::ParsedFile,
  :default_target => fstab,
  :filetype => :flat
) do
  include Puppet::Provider::Mount

  commands :mountcmd => "mount", :umount => "umount"

  case Facter.value(:osfamily)
  when "Solaris"
    @fields = [:device, :blockdevice, :name, :fstype, :pass, :atboot, :options]
  else
    @fields = [:device, :name, :fstype, :options, :dump, :pass]
  end

  if Facter.value(:osfamily) == "AIX"
    # * is the comment character on AIX /etc/filesystems
    text_line :comment, :match => /^\s*\*/
  else
    text_line :comment, :match => /^\s*#/
  end
  text_line :blank, :match => /^\s*$/

  optional_fields  = @fields - [:device, :name, :blockdevice]
  mandatory_fields = @fields - optional_fields

  # fstab will ignore lines that have fewer than the mandatory number of columns,
  # so we should, too.
  field_pattern = '(\s*(?>\S+))'
  text_line :incomplete, :match => /^(?!#{field_pattern}{#{mandatory_fields.length}})/

  case Facter.value(:osfamily)
  when "AIX"
    # The only field that is actually ordered is :name. See `man filesystems` on AIX
    @fields = [:name, :account, :boot, :check, :dev, :free, :mount, :nodename,
               :options, :quota, :size, :type, :vfs, :vol, :log]
    self.line_separator = "\n"
    # Override lines and use scan instead of split, because we DON'T want to
    # remove the separators
    def self.lines(text)
      # Separate base on comments, blank lines, or a mountpoint followed by
      # anything that isn't a mountpoint, comment, or blank line.
      ret = text.scan(%r{(^\s*\*.*?$|^\s*?$|^\S+:(?:(?!(?:^\S+:|^\s+\*|^\s*$)).)*)}m).flatten
      ret.reject { |line| line.match(/^\* HEADER/) }
    end
    def self.header
      super.gsub(/^#/,'*')
    end

    record_line self.name,
      :fields    => @fields,
      :separator => /\n/,
      :block_eval => :instance do

      def post_parse(result)
        property_map = {
          :dev      => :device,
          :nodename => :device,
          :options  => :options,
          :vfs      => :fstype,
        }
        # Result is modified in-place instead of being returned; icky!
        memo = result.dup
        result.clear
        special_options = Array.new
        result[:name] = memo[:name].sub(%r{:$},'')
        result[:record_type] = memo[:record_type]
        memo.each do |_,k_v|
          if k_v and k_v.is_a?(String) and k_v.match("=")
            attr_name, attr_value = k_v.split("=",2).map(&:strip)
            if attr_map_name = property_map[attr_name.to_sym]
              # These are normal "options" options (see `man filesystems`)
              result[attr_map_name] = attr_value
            else
              # These /etc/filesystem attributes have no mount resource simile,
              # so are added to the "options" property for puppet's sake
              special_options << "#{attr_name}=#{attr_value}"
            end
          end
        end
        result[:options] = [result[:options],special_options.sort].flatten.compact.join(',')
      end
      def to_line(result)
        output = Array.new
        output << "#{result[:name]}:"
        if result[:device] and result[:device].match(%r{^/})
          output << "\tdev\t\t= #{result[:device]}"
        elsif result[:device]
          output << "\tdev\t\t= #{result[:name]}"
          output << "\tnodename\t= #{result[:device]}"
        else
          raise ArgumentError, "Field 'device' is required"
        end
        if result[:fstype]
          output << "\tvfs\t\t= #{result[:fstype]}"
        else
          raise ArgumentError, "Field 'fstype' is required"
        end
        if result[:options]
          options = result[:options].split(',')
          special_options = options.select do |x|
            x.match('=') and
              ["account", "boot", "check", "free", "mount", "size", "type",
               "vol", "log", "quota"].include? x.split('=').first
          end
          options = options - special_options
          special_options.sort.each do |x|
            k, v = x.split("=")
            output << "\t#{k}\t\t= #{v}"
          end
          output << "\toptions\t\t= #{options.sort.join(",")}" unless options.empty?
        end
        output.join("\n")
      end
    end
  else
    record_line self.name, :fields => @fields, :separator => /\s+/, :joiner => "\t", :optional => optional_fields
  end

  # Every entry in fstab is :unmounted until we can prove different
  def self.prefetch_hook(target_records)
    target_records.collect do |record|
      record[:ensure] = :unmounted if record[:record_type] == :parsed
      record
    end
  end

  def self.instances
    providers = super
    mounts = mountinstances.dup

    # Update fstab entries that are mounted
    providers.each do |prov|
      if mounts.delete({:name => prov.get(:name), :mounted => :yes}) then
        prov.set(:ensure => :mounted)
      end
    end

    # Add mounts that are not in fstab but mounted
    mounts.each do |mount|
      providers << new(:ensure => :ghost, :name => mount[:name])
    end
    providers
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
    regex = case Facter.value(:osfamily)
      when "Darwin"
        / on (?:\/private\/var\/automount)?(\S*)/
      when "Solaris", "HP-UX"
        /^(\S*) on /
      when "AIX"
        /^(?:\S*\s+\S+\s+)(\S+)/
      else
        / on (\S*)/
    end
    instances = []
    mount_output = mountcmd.split("\n")
    if mount_output.length >= 2 and mount_output[1] =~ /^[- \t]*$/
      # On some OSes (e.g. AIX) mount output begins with a header line
      # followed by a line consisting of dashes and whitespace.
      # Discard these two lines.
      mount_output[0..1] = []
    end
    mount_output.each do |line|
      if match = regex.match(line) and name = match.captures.first
        instances << {:name => name, :mounted => :yes} # Only :name is important here
      else
        raise Puppet::Error, "Could not understand line #{line} from mount output"
      end
    end
    instances
  end

  def flush
    needs_mount = @property_hash.delete(:needs_mount)
    super
    mount if needs_mount
  end
end
