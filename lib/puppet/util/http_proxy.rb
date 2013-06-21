module Puppet::Util::HttpProxy

  # Read HTTP proxy configurationm from Puppet's config file, or the
  # http_proxy environment variable - non-DRY dup of puppet/forge/repository.rb
  def self.http_proxy_env
    proxy_env = ENV["http_proxy"] || ENV["HTTP_PROXY"] || nil
    begin
      return URI.parse(proxy_env) if proxy_env
    rescue URI::InvalidURIError
      return nil
    end
    return nil
  end

  def self.http_proxy_host
    env = self.http_proxy_env

    if env and env.host then
      return env.host
    end

    if Puppet.settings[:http_proxy_host] == 'none'
      return nil
    end

    return Puppet.settings[:http_proxy_host]
  end

  def self.http_proxy_port
    env = self.http_proxy_env

    if env and env.port then
      return env.port
    end

    return Puppet.settings[:http_proxy_port]
  end

end
