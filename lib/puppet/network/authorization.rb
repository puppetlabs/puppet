require 'puppet/network/client_request'
require 'puppet/network/authconfig'

module Puppet::Network
  # Most of our subclassing is just so that we can get
  # access to information from the request object, like
  # the client name and IP address.
  class InvalidClientRequest < Puppet::Error; end
  module Authorization
    # Create our config object if necessary.  This works even if
    # there's no configuration file.
    def authconfig
      @authconfig ||= Puppet::Network::AuthConfig.main

      @authconfig
    end

    # This is just the logic of authorized? extracted so it's separate from
    # the logging
    def check_auth(request)
      if request.authenticated?
        if authconfig.exists?
          authconfig.allowed?(request)
        else
          Puppet.run_mode.master?
        end
      else
        false
      end
    end
    private :check_auth

    # Verify that our client has access.  We allow untrusted access to
    # puppetca methods but no others.
    def authorized?(request)
      msg = "#{request.authenticated? ? "authenticated" : "unauthenticated"} client #{request} access to #{request.call}"

      if check_auth(request)
        Puppet.notice "Allowing #{msg}"
        true
      else
        Puppet.notice "Denying #{msg}"
        false
      end
    end

    # Is this functionality available?
    def available?(request)
      if handler_loaded?(request.handler)
        return true
      else
        Puppet.warning "Client #{request} requested unavailable functionality #{request.handler}"
        return false
      end
    end

    # Make sure that this method is available and authorized.
    def verify(request)
      unless available?(request)
        raise InvalidClientRequest.new(
          "Functionality #{request.handler} not available"
        )
      end
      unless authorized?(request)
        raise InvalidClientRequest.new(
          "Host #{request} not authorized to call #{request.call}"
        )
      end
    end
  end
end

