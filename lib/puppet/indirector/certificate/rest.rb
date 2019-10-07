require 'puppet/ssl/certificate'
require 'puppet/indirector/rest'

# @deprecated
class Puppet::SSL::Certificate::Rest < Puppet::Indirector::REST
  desc "Find certificates over HTTP via REST."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
  use_srv_service(:ca)

  def find(request)
    result = super
    return nil unless result
    result.name = request.key unless result.name == request.key
    result
  end
end
