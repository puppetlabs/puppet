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
end
