require 'puppet/ssl'

#
# States
#
#  * NeedCACerts: Need CA certs
#  * NeedCRLs: Need CRLs
#  * NeedKey: Need a private key
#  * Done: Have CA & CRL
#  * Error: We failed
#
# @private
class Puppet::SSL::StateMachine
  class SSLState
    attr_reader :ssl_context

    def initialize(ssl_context)
      @ssl_context = ssl_context
      @cert_provider = Puppet::X509::CertProvider.new
      @ssl_provider = Puppet::SSL::SSLProvider.new
    end
  end

  class NeedCACerts < SSLState
    def initialize
      super(nil)
      @ssl_context = @ssl_provider.create_insecure_context
    end

    def next_state
      Puppet.debug("Loading CA certs")

      cacerts = @cert_provider.load_cacerts
      if cacerts
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts)
      else
        fetcher = Puppet::SSL::Fetcher.new(@ssl_context)
        pem = fetcher.fetch_cacerts
        cacerts = @cert_provider.load_cacerts_from_pem(pem)
        # verify cacerts before saving
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts)
        @cert_provider.save_cacerts(cacerts)
      end

      NeedCRLs.new(next_ctx)
    end
  end

  class NeedCRLs < SSLState
    def next_state
      Puppet.debug("Loading CRLs")

      case Puppet[:certificate_revocation]
      when :chain, :leaf
        crls = @cert_provider.load_crls
        if crls
          next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: crls)
        else
          fetcher = Puppet::SSL::Fetcher.new(@ssl_context)
          pem = fetcher.fetch_crls
          crls = @cert_provider.load_crls_from_pem(pem)
          # verify crls before saving
          next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: crls)
          @cert_provider.save_crls(crls)
        end
      else
        Puppet.info("Certificate revocation is disabled, skipping CRL download")
        next_ctx = @ssl_context
      end

      NeedKey.new(next_ctx)
    end
  end

  class NeedKey < SSLState; end

  # Run the state machine for CA certs and CRLs
  #
  # @return [Puppet::SSL::SSLContext] initialized SSLContext
  def ensure_ca_certificates
    final_state = run_machine(NeedCACerts.new, NeedKey)
    final_state.ssl_context
  end

  private

  def run_machine(state, stop)
    loop do
      Puppet.debug("Current SSL state #{state_name(state)}")

      state = state.next_state

      return state if state.is_a?(stop)
    end
  end

  def state_name(state)
    state.class.to_s.split('::').last
  end
end
