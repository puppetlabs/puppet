# frozen_string_literal: true
require 'net/http'
require 'uri'
require 'tempfile'

require_relative '../../../puppet/util/checksums'
require_relative '../../../puppet/type/file/data_sync.rb'

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

          define resolve($nameserver1, $nameserver2, $domain, $search) {
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
      [template](https://puppet.com/docs/puppet/latest/function.html#template)
      or [file](https://puppet.com/docs/puppet/latest/function.html#file)
      function.
    EOT

    # Store a checksum as the value, rather than the actual content.
    # Simplifies everything.
    munge do |value|
      if value == :absent
        value
      elsif value.is_a?(String) && checksum?(value)
        # XXX This is potentially dangerous because it means users can't write a file whose
        # entire contents are a plain checksum unless it is a Binary content.
        Puppet.puppet_deprecation_warning([
            #TRANSLATORS "content" is an attribute and should not be translated
            _('Using a checksum in a file\'s "content" property is deprecated.'),
            #TRANSLATORS "filebucket" is a resource type and should not be translated. The quoted occurrence of "content" is an attribute and should not be translated.
            _('The ability to use a checksum to retrieve content from the filebucket using the "content" property will be removed in a future release.'),
            #TRANSLATORS "content" is an attribute and should not be translated.
            _('The literal value of the "content" property will be written to the file.'),
            #TRANSLATORS "static catalogs" should not be translated.
            _('The checksum retrieval functionality is being replaced by the use of static catalogs.'),
            _('See https://puppet.com/docs/puppet/latest/static_catalogs.html for more information.')].join(" "),
            :file => @resource.file,
            :line => @resource.line
        ) if !@actual_content && !resource.parameter(:source)
        value
      else
        @actual_content = value.is_a?(Puppet::Pops::Types::PBinaryType::Binary) ? value.binary_buffer : value
        resource.parameter(:checksum).sum(@actual_content)
      end
    end

    # Checksums need to invert how changes are printed.
    def change_to_s(currentvalue, newvalue)
      # Our "new" checksum value is provided by the source.
      source = resource.parameter(:source) 
      tmp = source.checksum if source
      if tmp
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
      checksum_insync?(contents_prop, is, !resource[:content].nil?) {|inner| super(inner)}
    end

    def property_matches?(current, desired)
      # If checksum_value is specified, it overrides comparing the content field.
      checksum_type = resource.parameter(:checksum).value
      checksum_value = resource.parameter(:checksum_value)
      if checksum_value
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
      # treat the value as a bytestring
      value = value.b if value.is_a?(String)
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
      dipper = resource.bucket
      raise "Could not get filebucket from file" unless dipper

      sum = should.sub(/\{\w+\}/, '')

      dipper.getfile(sum)
    rescue => detail
      self.fail Puppet::Error, "Could not retrieve content for #{should} from filebucket: #{detail}", detail
    end
  end
end
