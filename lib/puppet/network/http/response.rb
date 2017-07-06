class Puppet::Network::HTTP::Response
  def initialize(handler, response)
    @handler = handler
    @response = response
  end

  def respond_with(code, type, body)
    @handler.set_content_type(@response, type)
    @handler.set_response(@response, body, code)
  end
end
