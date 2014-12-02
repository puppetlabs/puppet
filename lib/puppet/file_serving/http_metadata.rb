require 'puppet/file_serving/metadata'

# Simplified metadata representation, suitable for the information
# that is available from HTTP headers.
class Puppet::FileServing::HttpMetadata < Puppet::FileServing::Metadata

  def initialize(http_response, path = '/dev/null')
    super(path)

    # ignore options that do not apply to HTTP metadata
    @owner = @group = @mode = nil

    @checksum_type = 'mtime'
    mtime = DateTime.httpdate(http_response['last-modified'])
    @checksum = "{mtime}#{mtime}"

    @ftype = 'file'

    self
  end
end
