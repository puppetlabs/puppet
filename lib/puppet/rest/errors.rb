module Puppet::Rest
  class ResponseError < Puppet::Error
    attr_reader :response

    # Error thrown when request status is not OK.
    # @param [String] msg the error message
    # @param [Puppet::Rest::Response] response the response from the failed
    #                                 request
    def initialize(msg, response = nil)
      super(msg)
      @response = response
    end
  end
end
