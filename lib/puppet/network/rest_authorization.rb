require 'puppet/network/client_request'
require 'puppet/network/rest_authconfig'

module Puppet::Network

    module RestAuthorization


        # Create our config object if necessary. If there's no configuration file
        # we install our defaults
        def authconfig
            unless defined? @authconfig
                @authconfig = Puppet::Network::RestAuthConfig.main
            end

            @authconfig
        end

        # Verify that our client has access.  We allow untrusted access to
        # certificates terminus but no others.
        def check_authorization(request)
            if request.authenticated?
                authenticated_authorized?(request)
            else
                unless unauthenticated_authorized?(request)
                    msg = "%s access to %s [%s]" % [ (request.node.nil? ? request.ip : "#{request.node}(#{request.ip})"), request.indirection_name, request.method ]
                    Puppet.warning("Denying access: " + msg)
                    raise AuthorizationError.new( "Forbidden request:" + msg )
                end
            end
        end

        # delegate to our authorization file
        def authenticated_authorized?(request)
            authconfig.allowed?(request)
        end

        # allow only certificate requests when not authenticated
        def unauthenticated_authorized?(request)
            request.indirection_name == :certificate or request.indirection_name == :certificate_request
        end
    end
end

