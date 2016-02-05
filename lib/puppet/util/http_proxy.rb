require 'uri'
require 'openssl'

module Puppet::Util::HttpProxy
  def self.proxy(uri)
    if self.no_proxy?(uri)
      proxy_class = Net::HTTP::Proxy(nil)
    else
      proxy_class = Net::HTTP::Proxy(self.http_proxy_host, self.http_proxy_port, self.http_proxy_user, self.http_proxy_password)
    end

    return proxy_class.new(uri.host, uri.port)
  end

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

  # The documentation around the format of the no_proxy variable seems
  # inconsistent.  Some suggests the use of the * as a way of matching any
  # hosts under a domain, e.g.:
  #   *.example.com
  # Other documentation suggests that just a leading '.' indicates a domain
  # level exclusion, e.g.:
  #   .example.com
  # We'll accomodate both here.
  def self.no_proxy?(dest)
    unless no_proxy_env = ENV["no_proxy"] || ENV["NO_PROXY"]
      return false
    end

    unless dest.is_a? URI
      begin
        dest = URI.parse(dest)
      rescue URI::InvalidURIError
        return false
      end
    end

    no_proxy_env.split(/\s*,\s*/).each do |d|
      host, port = d.split(':')
      host = Regexp.escape(host).gsub('\*', '.*')

      #If the host of this no_proxy value starts with '.', this entry is
      #a domain level entry. Don't pin the regex to the beginning of the entry.
      #If it does not start with a '.' then it is a host specific entry and
      #should be matched to the destination starting at the beginning.
      unless host =~ /^\\\./
        host = "^#{host}"
      end

      #If this no_proxy entry specifies a port, we want to match it against
      #the destination port.  Otherwise just match hosts.
      if port
        no_proxy_regex  = %r(#{host}:#{port}$)
        dest_string     = "#{dest.host}:#{dest.port}"
      else
        no_proxy_regex  = %r(#{host}$)
        dest_string     = "#{dest.host}"
      end

      if no_proxy_regex.match(dest_string)
        return true
      end
    end

    return false
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
    proxy = proxy(uri)

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

  # Retrieve a document through HTTP(s), following redirects if necessary.
  # 
  # Based on the the client implementation in the HTTP pool.
  #
  # @see Puppet::Network::HTTP::Connection#request_with_redirects
  #
  # @param [URI] uri The address of the resource to retrieve.
  # @param [symbol] method The name of the Net::HTTP method to use, typically :get, :head, :post etc.
  # @param [FixNum] redirect_limit The number of redirections that can be followed.
  # @return [Net::HTTPResponse] a response object
  def self.request_with_redirects(uri, method, redirect_limit = 10, &block)
    current_uri = uri
    response = nil

    0.upto(redirect_limit) do |redirection|
      proxy = get_http_object(current_uri)
      response = proxy.send(:head, current_uri.path)

      if [301, 302, 307].include?(response.code.to_i)
        # handle the redirection
        current_uri = URI.parse(response['location'])
        next
      end

      if block_given?
        headers = {'Accept' => 'binary', 'accept-encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'}
        response = proxy.send("request_#{method}".to_sym, current_uri.path, headers, &block)
      else
        response = proxy.send(method, current_uri.path)
      end

      Puppet.debug("HTTP #{method.to_s.upcase} request to #{current_uri} returned #{response.code} #{response.message}")

      return response
    end

    raise RedirectionLimitExceededException, "Too many HTTP redirections for #{uri}"
  end
end
