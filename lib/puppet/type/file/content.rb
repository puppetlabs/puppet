require 'net/http'
require 'uri'
require 'tempfile'

require 'puppet/util/checksums'
require 'puppet/type/file/data_sync.rb'

module Puppet
  Puppet::Type.type(:file).newproperty(:content) do
    include Puppet::Util::Checksums
    include Puppet::DataSync

    attr_reader :actual_content

    desc <<-'EOT'
      The desired contents of a file, as a string. This attribute is mutually
      exclusive with `source` and `target`.

      Newlines and tabs can be specified in double-quoted strings using
      standard escaped syntax --- \n for a newline, and \t for a tab.

      With very small files, you can construct content strings directly in
      the manifest...

          define resolve(nameserver1, nameserver2, domain, search) {
              $str = "search ${search}
                  domain ${domain}
                  nameserver ${nameserver1}
                  nameserver ${nameserver2}
                  "

              file { '/etc/resolv.conf':
                content => $str,
              }
          }

      ...but for larger files, this attribute is more useful when combined with the
      [template](https://docs.puppetlabs.com/puppet/latest/reference/function.html#template)
      or [file](https://docs.puppetlabs.com/puppet/latest/reference/function.html#file)
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
        # Asserts that nothing has changed since validate ran.
        devfail "content property should not exist if source and checksum_value are specified"
      end

      contents_prop = resource.parameter(:source) || self
      checksum_insync?(contents_prop, is, !resource[:content].nil?) {|_is| super(_is)}
    end

    def property_matches?(current, desired)
      # If checksum_value is specified, it overrides comparing the content field.
      checksum_type = resource.parameter(:checksum).value
      if checksum_value = resource.parameter(:checksum_value)
        desired = "{#{checksum_type}}#{checksum_value.value}"
      end

      # The inherited equality is always accepted, so use it if valid.
      return true if super(current, desired)
      return date_matches?(checksum_type, current, desired)
    end

    def retrieve
      retrieve_checksum(resource)
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
      contents_sync(resource.parameter(:source) || self)
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
