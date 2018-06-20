class ConstantErrorValidator
  def initialize(args)
    @fails_with = args[:fails_with]
    @error_string = args[:error_string] || ""
    @peer_certs = args[:peer_certs] || []
  end

  def setup_connection(connection)
    connection.stubs(:start).raises(OpenSSL::SSL::SSLError.new(@fails_with))
  end

  def peer_certs
    @peer_certs
  end

  def verify_errors
    [@error_string]
  end
end

class NoProblemsValidator
  def initialize(cert)
    @cert = cert
  end

  def setup_connection(connection)
  end

  def peer_certs
    [@cert]
  end

  def verify_errors
    []
  end
end

