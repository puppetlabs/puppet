require 'puppet/file_serving/terminus_helper'
require 'puppet/network/http/proxy_helper'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  class <<self
    attr_accessor :http_method
  end

  def find(request)
    uri = URI( unescape_url(request.key) )
    method = self.class.http_method

    proxy = Puppet::Network::HTTP::ProxyHelper.get_http_object(uri)

    response = proxy.send(method, uri.path)

    Puppet.debug("HTTP #{method.to_s.upcase} request to #{uri} returned #{response.code} #{response.message}")

    response
  end
end
