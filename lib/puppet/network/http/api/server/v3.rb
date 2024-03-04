# frozen_string_literal: true

require_relative 'v3/environments'
require_relative '../../../../../puppet/network/http/api/indirected_routes'

module Puppet
  module Network
    module HTTP
      class API
        module Server
          class V3
            def self.wrap(&block)
              lambda do |request, response|
                Puppet::Network::Authorization
                  .check_external_authorization(request.method,
                                                request.path)

                block.call.call(request, response)
              end
            end

            INDIRECTED = Puppet::Network::HTTP::Route
                         .path(/.*/)
                         .any(wrap { Puppet::Network::HTTP::API::IndirectedRoutes.new })

            ENVIRONMENTS = Puppet::Network::HTTP::Route
                           .path(%r{^/environments$})
                           .get(wrap { Environments.new(Puppet.lookup(:environments)) })

            def self.routes
              Puppet::Network::HTTP::Route.path(/v3/)
                                          .any
                                          .chain(ENVIRONMENTS, INDIRECTED)
            end
          end
        end
      end
    end
  end
end
