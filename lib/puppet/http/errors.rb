module Puppet::HTTP
  class HTTPError < Puppet::Error; end

  class ConnectionError < HTTPError; end

  class ResponseError < HTTPError
    attr_reader :response

    def initialize(response)
      super(response.reason)
      @response = response
    end
  end
end
