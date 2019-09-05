module Puppet::HTTP
  class HTTPError < Puppet::Error; end

  class ConnectionError < HTTPError; end

  class ProtocolError < HTTPError; end

  class TooManyRedirects < HTTPError
    def initialize(addr)
      super(_("Too many HTTP redirections for %{addr}") % { addr: addr})
    end
  end
end
