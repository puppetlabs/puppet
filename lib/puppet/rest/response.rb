module Puppet::Rest
  # This is a wrapper for the HTTP::Message class of the HTTPClient
  # gem. It is designed to wrap a message sent as an HTTP response.
  class Response
    def initialize(message)
      @message = message
    end

    def body
      @message.body
    end

    def content_type
      @message.content_type
    end

    def content_encoding
      @message.headers['Content-Encoding']
    end

    def status_code
      @message.status
    end

    def ok?
      @message.ok?
    end

    # Process and return the body of the response
    # @return [String] the decompressed body of the response
    def read_body
      if content_type
        decompress_body
      else
        Puppet.err _("No content type in http response; cannot parse")
      end
    end

    # Return the decompressed response body. Returns the body as-is
    # if not compressed.
    # @return [string] decompressed response body
    def decompress_body
      Puppet::Rest::Compression.decompress(content_encoding, body)
    end
  end
end
