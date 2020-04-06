# Base pool for HTTP connections.
#
# @api private
class Puppet::Network::HTTP::BasePool
  def start(site, verifier, http)
    Puppet.debug("Starting connection for #{site}")
    if site.use_ssl?
      verifier.setup_connection(http)
      begin
        http.start
        print_ssl_info(http) if Puppet::Util::Log.sendlevel?(:debug)
      rescue OpenSSL::SSL::SSLError => error
        verifier.handle_connection_error(http, error)
      end
    else
      http.start
    end
  end

  private

  def print_ssl_info(http)
    buffered_io = http.instance_variable_get(:@socket)
    return unless buffered_io

    socket = buffered_io.io
    return unless socket

    cipher = if Puppet::Util::Platform.jruby?
               socket.cipher
             else
               socket.cipher.first
             end
    Puppet.debug("Using #{socket.ssl_version} with cipher #{cipher}")
  end
end
