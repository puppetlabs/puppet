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
        socket = http.instance_variable_get(:@socket)
        Puppet.info("Using #{socket.io.ssl_version} with cipher #{socket.io.cipher.first}")
        # This is useful for debugging, but it leaks sensitive data so is
        # commented out
        puts socket.io.session.to_text
      rescue OpenSSL::SSL::SSLError => error
        verifier.handle_connection_error(http, error)
      end
    else
      http.start
    end
  end
end
