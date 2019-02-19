# Base pool for HTTP connections.
#
# @api private
class Puppet::Network::HTTP::BasePool
  def start(site, verifier, http)
    Puppet.debug("Starting connection for #{site}")
    if verifier
      verifier.setup_connection(http)
      begin
        http.start
      rescue OpenSSL::SSL::SSLError => error
        verifier.handle_connection_error(http, error)
      end
    else
      http.start
    end
  end
end
