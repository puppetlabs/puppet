require 'puppet/file_serving/http_metadata'
require 'puppet/indirector/generic_http'
require 'puppet/indirector/file_metadata'
require 'net/http'

class Puppet::Indirector::FileMetadata::Http < Puppet::Indirector::GenericHttp
  desc "Retrieve file metadata from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  def find(request)
    checksum_type = request.options[:checksum_type]
    uri = URI(request.uri)
    client = Puppet.runtime[:http]
    head = client.head(uri, options: {include_system_store: true})

    return create_httpmetadata(head, checksum_type) if head.success?

    case head.code
    when 403
      # AMZ presigned URL?
      if head.each_header.find { |k,_| k =~ /^x-amz-/i }
        get = partial_get(client, uri)
        return create_httpmetadata(get, checksum_type) if get.success?
      end
    when 405
      get = partial_get(client, uri)
      return create_httpmetadata(get, checksum_type) if get.success?
    end

    nil
  end

  def search(request)
    raise Puppet::Error, _("cannot lookup multiple files")
  end

  private

  def partial_get(client, uri)
    client.get(uri, headers: {'Range' => 'bytes=0-0'}, options: {include_system_store: true})
  end

  def create_httpmetadata(http_request, checksum_type)
    metadata = Puppet::FileServing::HttpMetadata.new(http_request)
    metadata.checksum_type = checksum_type if checksum_type
    metadata.collect
    metadata
  end
end
