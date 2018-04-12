require 'puppet'

module Puppet
  module Routes
    cert = {
      :server => Puppet.settings[:ca_server],
      :port => Puppet.settings[:ca_port],
      :srv_service => :ca,
      :get => "/puppet-ca/v1/certificate/ca"
    }

    def certificate(name)
      # but this doesn't have the server fallback logic...
      "#{cert[:server]}/#{cert[:port]}/puppet-ca/v1/certificate/#{name}"
    end

    # I want to be to able to do something like
    # http.get(Puppet::Routes.certificate(name), environment, 
  end
end

