# frozen_string_literal: true

require 'uri'
require_relative '../../puppet/ssl/openssl_loader'

module Puppet::HTTP::Proxy
  def self.proxy(uri)
    if http_proxy_host && !no_proxy?(uri)
      Net::HTTP.new(uri.host, uri.port, self.http_proxy_host, self.http_proxy_port, self.http_proxy_user, self.http_proxy_password)
    else
      http = Net::HTTP.new(uri.host, uri.port, nil, nil, nil, nil)
      # Net::HTTP defaults the proxy port even though we said not to
      # use one. Set it to nil so caller is not surprised
      http.proxy_port = nil
      http
    end
  end

  def self.http_proxy_env
    # Returns a URI object if proxy is set, or nil
    proxy_env = ENV.fetch("http_proxy", nil) || ENV.fetch("HTTP_PROXY", nil)
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
  # We'll accommodate both here.
  def self.no_proxy?(dest)
    no_proxy = self.no_proxy
    unless no_proxy
      return false
    end

    unless dest.is_a? URI
      begin
        dest = URI.parse(dest)
      rescue URI::InvalidURIError
        return false
      end
    end

    no_proxy.split(/\s*,\s*/).each do |d|
      host, port = d.split(':')
      host = Regexp.escape(host).gsub('\*', '.*')

      # If this no_proxy entry specifies a port, we want to match it against
      # the destination port.  Otherwise just match hosts.
      if port
        no_proxy_regex  = %r{#{host}:#{port}$}
        dest_string     = "#{dest.host}:#{dest.port}"
      else
        no_proxy_regex  = %r{#{host}$}
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

  def self.no_proxy
    no_proxy_env = ENV.fetch("no_proxy", nil) || ENV.fetch("NO_PROXY", nil)

    if no_proxy_env
      return no_proxy_env
    end

    if Puppet.settings[:no_proxy] == 'none'
      return nil
    end

    return Puppet.settings[:no_proxy]
  end
end
