require 'puppet/file_serving/terminus_helper'
require 'net/http'
require 'puppet/network/http_pool'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  class <<self
    attr_accessor :http_method
  end

  def find(request)
    uri = URI( unescape_url(request.key) )

    use_ssl = uri.scheme == 'https'
    connection = Puppet::Network::HttpPool.http_instance(uri.host, uri.port, use_ssl)
    method = self.class.http_method

    response = connection.send(method, uri.path)

    Puppet.debug("HTTP #{method.to_s.upcase} request to #{uri} returned #{response.code} #{response.message}")

    response
  end
end
