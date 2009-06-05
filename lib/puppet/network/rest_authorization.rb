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

        # Verify that our client has access.
        def check_authorization(request)
            authconfig.allowed?(request)
        end
    end
end

