module Puppet::Rest
  class SSLContext

    attr_reader :verify_mode, :cert_store

    # @param [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER] verify_mode
    # @param [OpenSSL::X509::SSLStore] cert_store
    def initialize(verify_mode, cert_store = OpenSSL::X509::Store.new)
      @verify_mode = verify_mode
      @cert_store = cert_store
    end
  end
end
