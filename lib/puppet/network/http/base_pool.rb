# Base pool for HTTP connections.
#
# @api private
class Puppet::Network::HTTP::BasePool
  def start(site, verify, http)
    Puppet.debug("Starting connection for #{site}")
    if verify
      verify.setup_connection(http)
      begin
        http.start
      rescue OpenSSL::SSL::SSLError => error
        Puppet::Util::SSL.handle_connection_error(error, verify, site.host)
      end
    else
      http.start
    end
  end
end
