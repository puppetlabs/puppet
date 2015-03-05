require 'uri'
require 'openssl'

module Puppet::Util::HttpProxy

  def self.http_proxy_env
    # Returns a URI object if proxy is set, or nil
    proxy_env = ENV["http_proxy"] || ENV["HTTP_PROXY"]
    begin
      return URI.parse(proxy_env) if proxy_env
    rescue URI::InvalidURIError
      return nil
    end
    return nil
  end

  def self.http_proxy_host
    env = self.http_proxy_env

    if env and env.host
      return env.host
    end

    if Puppet.settings[:http_proxy_host] == 'none'
      return nil
    end

    return Puppet.settings[:http_proxy_host]
  end

  def self.http_proxy_port
    env = self.http_proxy_env

    if env and env.port
      return env.port
    end

    return Puppet.settings[:http_proxy_port]
  end

  def self.http_proxy_user
    env = self.http_proxy_env

    if env and env.user
      return env.user
    end

    if Puppet.settings[:http_proxy_user] == 'none'
      return nil
    end

    return Puppet.settings[:http_proxy_user]
  end

  def self.http_proxy_password
    env = self.http_proxy_env

    if env and env.password
      return env.password
    end

    if Puppet.settings[:http_proxy_user] == 'none' or Puppet.settings[:http_proxy_password] == 'none'
      return nil
    end

    return Puppet.settings[:http_proxy_password]
  end

  # Return a Net::HTTP::Proxy object.
  #
  # This method optionally configures SSL correctly if the URI scheme is
  # 'https', including setting up the root certificate store so remote server
  # SSL certificates can be validated.
  #
  # @param [URI] uri The URI that is to be accessed.
  # @return [Net::HTTP::Proxy] object constructed tailored for the passed URI
  def self.get_http_object(uri)
    proxy_class = Net::HTTP::Proxy(http_proxy_host, http_proxy_port, http_proxy_user, http_proxy_password)
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
