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
          #TRANSLATORS 'Ensure' is an attribute and ':present' is a value and should not be translated
          resource.warning _("Ensure set to :present but file type is %{file_type} so no content will be synced") % { file_type: s.ftype}
        end
        return true
      end

      return true if ! resource.replace?

      is_insync = yield(is)

      if show_diff?(!is_insync)
        if param.sensitive
          send resource[:loglevel], "[diff redacted]"
        else
          write_temporarily(param) do |path|
            send resource[:loglevel], "\n" + diff(resource[:path], path)
          end
        end
      end
      is_insync
    end

    def show_diff?(has_changes)
      has_changes && Puppet[:show_diff] && resource.show_diff?
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
