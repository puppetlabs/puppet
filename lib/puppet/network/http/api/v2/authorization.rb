class Puppet::Network::HTTP::API::V2::Authorization
  include Puppet::Network::Authorization

  def call(request, response)
    raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, "Only GET requests are authorized for V2 endpoints" unless request.method == "GET"

    begin
      check_authorization(:find, request.path, request.params)
    rescue Puppet::Network::AuthorizationError => e
      raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, e.message
    end
  end
end
