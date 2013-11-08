# Perform no SSL verification
# @api private
class Puppet::SSL::NoValidator
  def setup_connection(connection)
    connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def peer_certs
    []
  end

  def verify_errors
    []
  end
end
