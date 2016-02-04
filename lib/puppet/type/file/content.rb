require 'net/http'
require 'uri'
require 'tempfile'
require 'date'

require 'puppet/util/checksums'

module Puppet
  Puppet::Type.type(:file).newproperty(:content) do
    include Puppet::Util::Diff
    include Puppet::Util::Checksums

    attr_reader :actual_content

    desc <<-'EOT'
      The desired contents of a file, as a string. This attribute is mutually
      exclusive with `source` and `target`.

      Newlines and tabs can be specified in double-quoted strings using
      standard escaped syntax --- \n for a newline, and \t for a tab.

      With very small files, you can construct content strings directly in
      the manifest...

          define resolve(nameserver1, nameserver2, domain, search) {
              $str = "search $search
                  domain $domain
                  nameserver $nameserver1
                  nameserver $nameserver2
                  "

              file { "/etc/resolv.conf":
                content => "$str",
              }
          }

      ...but for larger files, this attribute is more useful when combined with the
      [template](https://docs.puppetlabs.com/references/latest/function.html#template)
      or [file](https://docs.puppetlabs.com/references/latest/function.html#file)
      function.
    EOT

    # Store a checksum as the value, rather than the actual content.
    # Simplifies everything.
    munge do |value|
      if value == :absent
        value
      elsif checksum?(value)
        # XXX This is potentially dangerous because it means users can't write a file whose
        # entire contents are a plain checksum
        value
      else
        @actual_content = value
        resource.parameter(:checksum).sum(value)
      end
    end

    # Checksums need to invert how changes are printed.
    def change_to_s(currentvalue, newvalue)
      # Our "new" checksum value is provided by the source.
      if source = resource.parameter(:source) and tmp = source.checksum
        newvalue = tmp
      end
      if currentvalue == :absent
        return "defined content as '#{newvalue}'"
      elsif newvalue == :absent
        return "undefined content from '#{currentvalue}'"
      else
        return "content changed '#{currentvalue}' to '#{newvalue}'"
      end
    end

    def length
      (actual_content and actual_content.length) || 0
    end

    def content
      self.should
    end

    # Override this method to provide diffs if asked for.
    # Also, fix #872: when content is used, and replace is true, the file
    # should be insync when it exists
    def insync?(is)
      if resource[:source] && resource[:checksum_value]
        self.fail Puppet::Error, "Content should not exist if source and checksum_value are specified"
      end

      if resource.should_be_file?
        return false if is == :absent
      else
        if resource[:ensure] == :present and resource[:content] and s = resource.stat
          resource.warning "Ensure set to :present but file type is #{s.ftype} so no content will be synced"
        end
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
      # If checksum_value is specified, it overrides comparing the content field.
      checksum_type = resource.parameter(:checksum).value
      if checksum_value = resource.parameter(:checksum_value)
        desired = "{#{checksum_type}}#{checksum_value.value}"
      end

      basic = super(current, desired)
      # The inherited equality is always accepted, so use it if valid.
      time_types = [:mtime, :ctime]
      return basic if basic || !time_types.include?(checksum_type)
      return false unless current && desired
      begin
        raise if !time_types.include?(sumtype(current).to_sym) || !time_types.include?(sumtype(desired).to_sym)
        DateTime.parse(sumdata(current)) >= DateTime.parse(sumdata(desired))
      rescue => detail
        self.fail Puppet::Error, "Resource with checksum_type #{checksum_type} didn't contain a date in #{current} or #{desired}", detail.backtrace
      end
    end

    def retrieve
      return :absent unless stat = @resource.stat
      ftype = stat.ftype
      # Don't even try to manage the content on directories or links
      return nil if ["directory","link"].include?(ftype)

      begin
        resource.parameter(:checksum).sum_file(resource[:path])
      rescue => detail
        raise Puppet::Error, "Could not read #{ftype} #{@resource.title}: #{detail}", detail.backtrace
      end
    end

    # Make sure we're also managing the checksum property.
    def should=(value)
      # treat the value as a bytestring, in Ruby versions that support it, regardless of the encoding
      # in which it has been supplied
      value = value.dup.force_encoding(Encoding::ASCII_8BIT) if value.respond_to?(:force_encoding)
      @resource.newattr(:checksum) unless @resource.parameter(:checksum)
      super
    end

    # Just write our content out to disk.
    def sync
      return_event = @resource.stat ? :file_changed : :file_created

      # We're safe not testing for the 'source' if there's no 'should'
      # because we wouldn't have gotten this far if there weren't at least
      # one valid value somewhere.
      @resource.write

      return_event
    end

    def write(file)
      resource.parameter(:checksum).sum_stream { |sum|
        each_chunk_from { |chunk|
          sum << chunk
          file.print chunk
        }
      }
    end

    private

    # the content is munged so if it's a checksum source_or_content is nil
    # unless the checksum indirectly comes from source
    def each_chunk_from
      if actual_content.is_a?(String)
        yield actual_content
      elsif content_is_really_a_checksum? && actual_content.nil?
        yield read_file_from_filebucket
      elsif actual_content.nil?
        yield ''
      end
    end

    def content_is_really_a_checksum?
      checksum?(should)
    end

    def read_file_from_filebucket
      raise "Could not get filebucket from file" unless dipper = resource.bucket
      sum = should.sub(/\{\w+\}/, '')

      dipper.getfile(sum)
    rescue => detail
      self.fail Puppet::Error, "Could not retrieve content for #{should} from filebucket: #{detail}", detail
    end
  end
end
