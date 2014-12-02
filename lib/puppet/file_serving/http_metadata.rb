require 'puppet/file_serving/metadata'

# Simplified metadata representation, suitable for the information
# that is available from HTTP headers.
class Puppet::FileServing::HttpMetadata < Puppet::FileServing::Metadata

  def initialize(http_response, path = '/dev/null')
    super(path)

    # ignore options that do not apply to HTTP metadata
    @owner = @group = @mode = nil

    if checksum = http_response['content-md5']
      # convert base64 digest to hex
      checksum = checksum.unpack("m0").first.unpack("H*").first
      @checksum_type = 'md5'
      @checksum = "{md5}#{checksum}"
    elsif last_modified = http_response['last-modified']
      mtime = DateTime.httpdate(last_modified).to_time
      @checksum_type = 'mtime'
      @checksum = "{mtime}#{mtime}"
    else
      raise PuppetError, "HTTP response contained no usable checksum equivalent"
    end

    @ftype = 'file'

    self
  end
end
