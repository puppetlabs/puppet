require 'puppet/file_serving/metadata'
require 'puppet/indirector/generic_http'

class Puppet::Indirector::FileContent::Http < Puppet::Indirector::GenericHttp
  desc "Retrieve file contents from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  @http_method = :get

  def find(request)
    response = super
    model.from_binary(response.body)
  end
end
