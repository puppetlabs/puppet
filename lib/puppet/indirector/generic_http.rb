require 'puppet/file_serving/terminus_helper'
require 'net/http'
require 'puppet/util/http_proxy'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  class <<self
    attr_accessor :http_method
  end

  def find(request)
    uri = URI( unescape_url(request.key) )
    method = self.class.http_method

    proxy_class = Net::HTTP::Proxy(Puppet::Util::HttpProxy.http_proxy_host,
                                   Puppet::Util::HttpProxy.http_proxy_port,
                                   Puppet::Util::HttpProxy.http_proxy_user,
                                   Puppet::Util::HttpProxy.http_proxy_password)
    proxy = proxy_class.new(uri.host, uri.port)

    if uri.scheme == 'https'
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths

      proxy.use_ssl = true
      proxy.verify_mode = OpenSSL::SSL::VERIFY_PEER
      proxy.cert_store = cert_store
    end

    response = proxy.send(method, uri.path)

    Puppet.debug("HTTP #{method.to_s.upcase} request to #{uri} returned #{response.code} #{response.message}")

    response
  end
end
