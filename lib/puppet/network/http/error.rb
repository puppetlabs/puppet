module Puppet::Network::HTTP::Error
  class HTTPError < Exception
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  class HTTPNotAcceptableError < HTTPError
    CODE = 406
    def initialize(message)
      super("Not Acceptable: " + message, CODE)
    end
  end

  class HTTPNotFoundError < HTTPError
    CODE = 404
    def initialize(message)
      super("Not Found: " + message, CODE)
    end
  end

  class HTTPNotAuthorizedError < HTTPError
    CODE = 403
    def initialize(message)
      super("Not Authorized: " + message, CODE)
    end
  end

  class HTTPMethodNotAllowedError < HTTPError
    CODE = 405
    def initialize(message)
      super("Method Not Allowed: " + message, CODE)
    end
  end
end
