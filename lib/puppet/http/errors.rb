module Puppet::HTTP
  class HTTPError < Puppet::Error; end

  class ConnectionError < HTTPError; end
end
