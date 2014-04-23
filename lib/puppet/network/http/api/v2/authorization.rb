class Puppet::Network::HTTP::API::V2::Authorization
  include Puppet::Network::Authorization

  def call(request, response)
    if request.method != "GET"
      raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError.new("Only GET requests are authorized for V2 endpoints", Puppet::Network::HTTP::Issues::UNSUPPORTED_METHOD)
    end

    begin
      check_authorization(:find, request.path, request.params)
    rescue Puppet::Network::AuthorizationError => e
      raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError.new(e.message, Puppet::Network::HTTP::Issues::FAILED_AUTHORIZATION)
    end
  end
end
