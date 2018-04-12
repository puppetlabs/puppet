require 'puppet'

module Puppet::Rest
  module Resolution
    # @return [String, String] array of server and port to use for the request
    def self.select_server_and_port(srv_service: :puppet, default_server: nil, default_port: nil)
      if Puppet.settings[:use_srv_records]
        Puppet::Network::Resolver.each_srv_record(Puppet.settings[:srv_domain], srv_service) do |srv_server, srv_port|
          return [srv_server, srv_port]
        end
      end

      # Fall back to the default server, taking into account HA settings
      bound_server = Puppet.lookup(:server) do
        if primary_server = Puppet.settings[:server_list][0]
          primary_server[0]
        else
          Puppet.settings[:server]
        end
      end

      bound_port = Puppet.lookup(:serverport) do
        if primary_server = Puppet.settings[:server_list][0]
          primary_server[1]
        else
          Puppet.settings[:masterport]
        end
      end

      server = default_server || bound_server
      port = default_port || bound_port

      if Puppet.settings[:use_srv_records]
        Puppet.debug("No more server left, falling back to #{server}:#{port}")
      end

      return [server, port]
    end
  end
end
