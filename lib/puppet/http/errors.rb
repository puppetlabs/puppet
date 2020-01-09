module Puppet::HTTP
  class HTTPError < Puppet::Error; end

  class ConnectionError < HTTPError; end

  class RouteError < HTTPError; end

  class ProtocolError < HTTPError; end

  class SerializationError < HTTPError; end

  class ResponseError < HTTPError
    attr_reader :response

    def initialize(response)
      super(response.reason)
      @response = response
    end
  end

  class TooManyRedirects < HTTPError
    def initialize(addr)
      super(_("Too many HTTP redirections for %{addr}") % { addr: addr})
    end
  end

  class TooManyRetryAfters < HTTPError
    def initialize(addr)
      super(_("Too many HTTP retries for %{addr}") % { addr: addr})
    end
  end
end
