class Puppet::Network::HTTP::Response
  def initialize(handler, response)
    @handler = handler
    @response = response
  end

  def respond_with(code, type, body)
    format = Puppet::Network::FormatHandler.format_for(type)
    mime = format.mime
    charset = format.charset

    if charset
      if body.is_a?(String) && body.encoding != charset
        body.encode!(charset)
      end

      mime += "; charset=#{charset.name.downcase}"
    end

    @handler.set_content_type(@response, mime)
    @handler.set_response(@response, body, code)
  end
end
