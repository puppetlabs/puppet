require 'json'

module Puppet::Network::HTTP::Error
  Issues = Puppet::Network::HTTP::Issues

  class HTTPError < Exception
    attr_reader :status, :issue_kind

    def initialize(message, status, issue_kind)
      super(message)
      @status = status
      @issue_kind = issue_kind
    end

    def to_json
      JSON({:message => message, :issue_kind => @issue_kind})
    end
  end

  class HTTPNotAcceptableError < HTTPError
    CODE = 406
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Not Acceptable: ") + message, CODE, issue_kind)
    end
  end

  class HTTPNotFoundError < HTTPError
    CODE = 404
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Not Found: ") + message, CODE, issue_kind)
    end
  end

  class HTTPNotAuthorizedError < HTTPError
    CODE = 403
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Not Authorized: ") + message, CODE, issue_kind)
    end
  end

  class HTTPBadRequestError < HTTPError
    CODE = 400
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Bad Request: ") + message, CODE, issue_kind)
    end
  end

  class HTTPMethodNotAllowedError < HTTPError
    CODE = 405
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Method Not Allowed: ") + message, CODE, issue_kind)
    end
  end

  class HTTPServerError < HTTPError
    CODE = 500

    attr_reader :backtrace

    def initialize(original_error, issue_kind = Issues::RUNTIME_ERROR)
      super(_("Server Error: ") + original_error.message, CODE, issue_kind)
      @backtrace = ["Warning: The 'stacktrace' property is deprecated and will be removed in a future version of Puppet. For security reasons, stacktraces are not returned with Puppet HTTP Error responses."]
    end

    def to_json
      JSON({:message => message, :issue_kind => @issue_kind, :stacktrace => self.backtrace})
    end
  end
end
