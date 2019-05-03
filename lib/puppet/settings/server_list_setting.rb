class Puppet::Settings::ServerListSetting < Puppet::Settings::ArraySetting

  def type
    :server_list
  end

  def print(value)
    if value.is_a?(Array)
      #turn into a string
      value.map {|item| item.join(":") }.join(",")
    else
      value
    end
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
        raise ArgumentError, _("Expected an Array of String, got a %{klass}") % { klass: value.class }
      end
    }
  end
end
