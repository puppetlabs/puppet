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
      if body.is_a?(String)
        # REMIND: not all charsets are valid ruby encodings, e.g. ISO-2022-KR
        encoding = Encoding.find(charset)

        if body.encoding != encoding
          # REMIND this can raise if body contains invalid UTF-8
          body.encode!(encoding)
        end
      end

      mime += "; charset=#{charset}"
    end

    @handler.set_content_type(@response, mime)
    @handler.set_response(@response, body, code)
  end
end
