require 'puppet/file_serving/terminus_helper'
require 'puppet/util/http_proxy'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."

  class <<self
    attr_accessor :http_method
  end

  def find(request)
    uri = URI(request.uri)
    method = self.class.http_method

    proxy = Puppet::Util::HttpProxy.get_http_object(uri)

    response = proxy.send(method, uri.path)

    Puppet.debug("HTTP #{method.to_s.upcase} request to #{uri} returned #{response.code} #{response.message}")

    response
  end
end
