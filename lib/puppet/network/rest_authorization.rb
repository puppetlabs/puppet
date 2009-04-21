require 'puppet/network/client_request'
require 'puppet/network/rest_authconfig'

module Puppet::Network
    # Most of our subclassing is just so that we can get
    # access to information from the request object, like
    # the client name and IP address.
    class InvalidClientRequest < Puppet::Error; end
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
        def authorized?(request)
            msg = "%s client %s access to %s [%s]" %
                   [ request.authenticated? ? "authenticated" : "unauthenticated",
                    (request.node.nil? ? request.ip : "#{request.node}(#{request.ip})"),
                    request.indirection_name, request.method ]

            if request.authenticated?
                res = authenticated_authorized?(request, msg )
            else
                res = unauthenticated_authorized?(request, msg)
            end
            Puppet.notice((res ? "Allowing " : "Denying ") + msg)
            return res
        end

        # delegate to our authorization file
        def authenticated_authorized?(request, msg)
            authconfig.allowed?(request)
        end

        # allow only certificate requests when not authenticated
        def unauthenticated_authorized?(request, msg)
            request.indirection_name == :certificate or request.indirection_name == :certificate_request
        end
    end
end

