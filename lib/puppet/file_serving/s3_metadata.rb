require 'puppet/file_serving/metadata'

class Puppet::FileServing::S3Metadata < Puppet::FileServing::Metadata
  def initialize(s3_response, path = '/dev/null')
    super(path)

    # ignore options that do not apply to s3 metadata
    @owner = @group = @mode = nil

    if s3_response.etag
      @checksum_type = 'md5'
      # Strip the double quotes from the S3 etag response
      @checksum = "{md5}#{s3_response.etag.tr('"','')}"
    else
      raise PuppetError, "S3 response contained no usable checksum equivalant"
    end

    @ftype = 'file'

    self
  end
end
