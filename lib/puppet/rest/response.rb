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

    def to_exception
      message = _("Error %{code} on SERVER: %{returned_message}") % { code: status_code, returned_message: body }
      Puppet::Rest::ResponseError.new(message, self)
    end
  end
end
