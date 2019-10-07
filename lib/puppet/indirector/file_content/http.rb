require 'puppet/file_serving/metadata'
require 'puppet/indirector/generic_http'
require 'puppet/network/http'

class Puppet::Indirector::FileContent::Http < Puppet::Indirector::GenericHttp
  desc "Retrieve file contents from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper
  include Puppet::Network::HTTP::Compression.module

  @http_method = :get

  def find(request)
    response = super
    model.from_binary(uncompress_body(response))
  end
end
