require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'net/http'
require 'puppet/network/http_pool'

class Puppet::Indirector::FileContent::Http < Puppet::Indirector::Plain
  desc "Retrieve file contents from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  def find(request)
    uri = URI( unescape_url(request.to_s) )

    use_ssl = uri.scheme == 'https'
    connection = Puppet::Network::HttpPool.http_instance(uri.host, uri.port, use_ssl)

    response = connection.get(uri.path)
    model.from_binary(response.body)
  end
end
