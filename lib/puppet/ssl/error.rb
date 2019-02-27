module Puppet::SSL
  class SSLError < Puppet::Error; end

  class CertVerifyError < Puppet::SSL::SSLError
    attr_reader :code, :cert
    def initialize(message, code, cert)
      super(message)
      @code = code
      @cert = cert
    end
  end
end
