require 'puppet/network/authorization'

class Puppet::Network::HTTP::API::Master::V3::Authorization
  include Puppet::Network::Authorization

  def wrap(&block)
    lambda do |request, response|
      begin
        authconfig.check_authorization(:find, request.path, request.params)
      rescue Puppet::Network::AuthorizationError => e
        raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError.new(e.message, Puppet::Network::HTTP::Issues::FAILED_AUTHORIZATION)
      end

      block.call.call(request, response)
    end
  end

end
