require 'puppet/util/checksums'

module Puppet
  Puppet::Type.type(:file).newproperty(:checksum_value) do
    include Puppet::Util::Checksums
    include Puppet::Util::Diff

    desc "The checksum of the source contents. Only md5 and sha256 are supported when
      specifying this parameter."

    def insync?(is)
      # If checksum_value is specified, only manage source.
      # Content manages its own syncing... FOR NOW, duh duh duh
      if resource.parameter(:source).nil?
        return true
      end

      if resource.should_be_file?
        return false if is == :absent
      else
        return true
      end

      return true if ! @resource.replace?

      result = super

      if ! result and Puppet[:show_diff] and resource.show_diff?
        resource.write_temporarily do |path|
          send @resource[:loglevel], "\n" + diff(@resource[:path], path)
        end
      end
      result
    end

    def property_matches?(current, desired)
      time_types = [:mtime, :ctime]
      checksum_type = resource.parameter(:checksum).value

      # The inherited equality is always accepted, so use it if valid.
      basic = super(current, desired)
      return basic if basic || !time_types.include?(checksum_type)
      return false unless current && desired
      begin
        DateTime.parse(current) >= DateTime.parse(desired)
      rescue => detail
        self.fail Puppet::Error, "Resource with checksum_type #{checksum_type} didn't contain a date in #{current} or #{desired}", detail.backtrace
      end
    end

    def sync
      # insync? only returns false if it expects to manage the file content,
      # so instruct the resource to write its contents.
      return_event = @resource.stat ? :file_changed : :file_created
      @resource.write
      return_event
    end

    def retrieve
      # Intentionally mirrors content#retrieve. Eventually content will be a
      # parameter, and content syncing will be managed by checksum_value.
      return :absent unless stat = @resource.stat
      ftype = stat.ftype
      # Don't even try to manage the content on directories or links
      return nil if ["directory","link"].include?(ftype)

      begin
        sumdata(resource.parameter(:checksum).sum_file(resource[:path]))
      rescue => detail
        raise Puppet::Error, "Could not read #{ftype} #{@resource.title}: #{detail}", detail.backtrace
      end
    end
  end
end
