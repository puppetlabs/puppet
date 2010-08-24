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

    # Verify that our client has access.  We allow untrusted access to
    # puppetca methods but no others.
    def authorized?(request)
      msg = "#{request.authenticated? ? "authenticated" : "unauthenticated"} client #{request} access to #{request.call}"

      if request.authenticated?
        if authconfig.exists?
          if authconfig.allowed?(request)
            Puppet.debug "Allowing #{msg}"
            return true
          else
            Puppet.notice "Denying #{msg}"
            return false
          end
        else
          if Puppet.run_mode.master?
            Puppet.debug "Allowing #{msg}"
            return true
          else
            Puppet.notice "Denying #{msg}"
            return false
          end
        end
      else
        if request.handler == "puppetca"
          Puppet.notice "Allowing #{msg}"
        else
          Puppet.notice "Denying #{msg}"
          return false
        end
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

