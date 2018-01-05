require 'puppet/file_serving/metadata'

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

    if checksum = http_response['content-md5']
      # convert base64 digest to hex
      checksum = checksum.unpack("m0").first.unpack("H*").first
      @checksums[:md5] = "{md5}#{checksum}"
    end

    if last_modified = http_response['last-modified']
      mtime = DateTime.httpdate(last_modified).to_time
      @checksums[:mtime] = "{mtime}#{mtime.utc}"
    end

    @ftype = 'file'

    self
  end

  # Override of the parent class method. Does not call super!
  # We can only return metadata that was extracted from the
  # HTTP headers during #initialize.
  def collect
    # Prefer the checksum_type from the indirector request options
    # but fall back to the alternative otherwise
    [ @checksum_type, :md5, :sha256, :sha384, :sha512, :sha224, :mtime ].each do |type|
      @checksum_type = type
      @checksum = @checksums[type]
      return if @checksum
    end
  end
end
