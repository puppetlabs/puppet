require 'puppet/util/checksums'
require 'puppet/util/diff'
require 'date'
require 'tempfile'

module Puppet
  module DataSync
    include Puppet::Util::Checksums
    include Puppet::Util::Diff

    def write_temporarily(param)
      tempfile = Tempfile.new("puppet-file")
      tempfile.open

      param.write(tempfile)

      tempfile.close

      yield tempfile.path
    ensure
      tempfile.delete if tempfile
    end

    def checksum_insync?(param, is, has_contents, &block)
      resource = param.resource
      if resource.should_be_file?
        return false if is == :absent
      else
        if resource[:ensure] == :present && has_contents && (s = resource.stat)
          resource.warning "Ensure set to :present but file type is #{s.ftype} so no content will be synced"
        end
        return true
      end

      return true if ! resource.replace?

      result = yield(is)

      if !result && Puppet[:show_diff] && resource.show_diff?
        write_temporarily(param) do |path|
          send resource[:loglevel], "\n" + diff(resource[:path], path)
        end
      end
      result
    end

    def date_matches?(checksum_type, current, desired)
      time_types = [:mtime, :ctime]
      return false if !time_types.include?(checksum_type)
      return false unless current && desired

      begin
        if checksum?(current) || checksum?(desired)
          raise if !time_types.include?(sumtype(current).to_sym) || !time_types.include?(sumtype(desired).to_sym)
          current = sumdata(current)
          desired = sumdata(desired)
        end
        DateTime.parse(current) >= DateTime.parse(desired)
      rescue => detail
        self.fail Puppet::Error, "Resource with checksum_type #{checksum_type} didn't contain a date in #{current} or #{desired}", detail.backtrace
      end
    end

    def retrieve_checksum(resource)
      return :absent unless stat = resource.stat
      ftype = stat.ftype
      # Don't even try to manage the content on directories or links
      return nil if ["directory","link"].include?(ftype)

      begin
        resource.parameter(:checksum).sum_file(resource[:path])
      rescue => detail
        raise Puppet::Error, "Could not read #{ftype} #{resource.title}: #{detail}", detail.backtrace
      end
    end

    def contents_sync(param)
      return_event = param.resource.stat ? :file_changed : :file_created
      resource.write(param)
      return_event
    end

  end
end
