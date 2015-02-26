require 'uri'
require 'openssl'
require 'puppet/util/http_proxy'

class Puppet::Network::HTTP::ProxyHelper

  # Return a Net::HTTP::Proxy object.
  #
  # This method optionally configures SSL correctly if the URI scheme is
  # 'https', including setting up the root certificate store so remote server
  # SSL certificates can be validated.
  #
  # @param [URI] uri The URI that is to be accessed.
  # @return [Net::HTTP::Proxy] object constructed tailored for the passed URI
  def self.get_http_object(uri)
    proxy_class = Net::HTTP::Proxy(Puppet::Util::HttpProxy.http_proxy_host, Puppet::Util::HttpProxy.http_proxy_port, Puppet::Util::HttpProxy.http_proxy_user, Puppet::Util::HttpProxy.http_proxy_password)
    proxy = proxy_class.new(uri.host, uri.port)

    if uri.scheme == 'https'
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths

      proxy.use_ssl = true
      proxy.verify_mode = OpenSSL::SSL::VERIFY_PEER
      proxy.cert_store = cert_store
    end

    if Puppet[:http_debug]
      proxy.set_debug_output($stderr)
    end

    proxy.open_timeout = Puppet[:http_connect_timeout]
    proxy.read_timeout = Puppet[:http_read_timeout]

    proxy
  end

end
