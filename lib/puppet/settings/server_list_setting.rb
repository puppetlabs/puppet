class Puppet::Settings::ServerListSetting < Puppet::Settings::ArraySetting

  def type
    :server_list
  end

  def munge(value)
    servers = super 
    servers.map! { |server| 
      case server
      when String
        server.split(':')
      when Array
        server
      else
        raise ArgumentError, "Expected an Array of String, got a #{value.class}"
      end
    }
  end
end
