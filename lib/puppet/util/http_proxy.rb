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
end
