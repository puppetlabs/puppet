# frozen_string_literal: true

require_relative '../../puppet/file_serving/metadata'

# Simplified metadata representation, suitable for the information
# that is available from HTTP headers.
class Puppet::FileServing::HttpMetadata < Puppet::FileServing::Metadata
  def initialize(http_response, path = '/dev/null')
    super(path)

    # ignore options that do not apply to HTTP metadata
    @owner = @group = @mode = nil

    # hash available checksums for eventual collection
    @checksums = {}
    # use a default mtime in case there is no usable HTTP header
    @checksums[:mtime] = "{mtime}#{Time.now}"

    # RFC-1864, deprecated in HTTP/1.1 due to partial responses
    checksum = http_response['content-md5']
    if checksum
      # convert base64 digest to hex
      checksum = checksum.unpack1("m").unpack1("H*")
      @checksums[:md5] = "{md5}#{checksum}"
    end

    {
      md5: 'X-Checksum-Md5',
      sha1: 'X-Checksum-Sha1',
      sha256: 'X-Checksum-Sha256'
    }.each_pair do |checksum_type, header|
      checksum = http_response[header]
      if checksum
        @checksums[checksum_type] = "{#{checksum_type}}#{checksum}"
      end
    end

    last_modified = http_response['last-modified']
    if last_modified
      mtime = DateTime.httpdate(last_modified).to_time
      @checksums[:mtime] = "{mtime}#{mtime.utc}"
    end

    @ftype = 'file'
  end

  # Override of the parent class method. Does not call super!
  # We can only return metadata that was extracted from the
  # HTTP headers during #initialize.
  def collect
    # Prefer the checksum_type from the indirector request options
    # but fall back to the alternative otherwise
    [@checksum_type, :sha256, :sha1, :md5, :mtime].each do |type|
      next if type == :md5 && Puppet::Util::Platform.fips_enabled?

      @checksum_type = type
      @checksum = @checksums[type]
      break if @checksum
    end
  end
end
