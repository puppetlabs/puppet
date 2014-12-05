require 'puppet/file_serving/http_metadata'
require 'puppet/indirector/file_metadata'
require 'net/http'
require 'puppet/network/http_pool'

class Puppet::Indirector::FileMetadata::Http < Puppet::Indirector::Plain
  desc "Retrieve file metadata from a remote HTTP server."

  def find(request)
    uri = URI( request.to_s.sub(%r{^/file_metadata/url=},'') )

    use_ssl = uri.scheme == 'https'
    connection = Puppet::Network::HttpPool.http_instance(uri.host, uri.port, use_ssl)

    response = connection.head(uri.path)
    Puppet::FileServing::HttpMetadata.new(response)
  end

  def search(request)
    raise Puppet::Error, "cannot lookup multiple files"
  end
end
