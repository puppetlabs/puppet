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
      super("Not Acceptable: " + message, CODE, issue_kind)
    end
  end

  class HTTPNotFoundError < HTTPError
    CODE = 404
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super("Not Found: " + message, CODE, issue_kind)
    end
  end

  class HTTPNotAuthorizedError < HTTPError
    CODE = 403
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super("Not Authorized: " + message, CODE, issue_kind)
    end
  end

  class HTTPBadRequestError < HTTPError
    CODE = 400
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super("Bad Request: " + message, CODE, issue_kind)
    end
  end

  class HTTPMethodNotAllowedError < HTTPError
    CODE = 405
    def initialize(message, issue_kind = Issues::RUNTIME_ERROR)
      super("Method Not Allowed: " + message, CODE, issue_kind)
    end
  end

  class HTTPServerError < HTTPError
    CODE = 500

    attr_reader :backtrace

    def initialize(original_error, issue_kind = Issues::RUNTIME_ERROR)
      super("Server Error: " + original_error.message, CODE, issue_kind)
      @backtrace = original_error.backtrace
    end

    def to_json
      JSON({:message => message, :issue_kind => @issue_kind, :stacktrace => self.backtrace})
    end
  end
end
