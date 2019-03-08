require 'puppet/ssl'

# This class implements a state machine for bootstrapping a host's CA and CRL
# bundles, private key and signed client certificate. Each state has a frozen
# SSLContext that it uses to make network connections. If a state makes progress
# bootstrapping the host, then the state will generate a new frozen SSLContext
# and pass that to the next state. For example, the NeedCACerts state will load
# or download a CA bundle, and generate a new SSLContext containing those CA
# certs. This way we're sure about which SSLContext is being used during any
# phase of the bootstrapping process.
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

  # Load existing CA certs or download them. Transition to NeedCRLs.
  #
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

  # If revocation is enabled, load CRLs or download them, using the CA bundle
  # from the previous state. Transition to NeedKey.
  #
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

  # Load or generate a private key. If the key exists, try to load the client cert
  # and transition to Done. If the cert is mismatched or otherwise fails valiation,
  # raise an error. If the key doesn't exist yet, generate one, and save it. If the
  # cert doesn't exist yet, transition to NeedSubmitCSR.
  #
  class NeedKey < SSLState
    def next_state
      key = @cert_provider.load_private_key(Puppet[:certname])
      if key
        cert = @cert_provider.load_client_cert(Puppet[:certname])
        if cert
          next_ctx = @ssl_provider.create_context(
            cacerts: @ssl_context.cacerts, crls: @ssl_context.crls, private_key: key, client_cert: cert
          )
          return Done.new(next_ctx)
        end
      else
        key = OpenSSL::PKey::RSA.new(Puppet[:keylength].to_i)
        @cert_provider.save_private_key(Puppet[:certname], key)
      end

      NeedSubmitCSR.new(@ssl_context, key)
    end
  end

  # Base class for states with a private key.
  #
  class KeySSLState < SSLState
    attr_reader :private_key

    def initialize(ssl_context, private_key)
      super(ssl_context)
      @private_key = private_key
    end
  end

  # Generate and submit a CSR using the CA cert bundle and optional CRL bundle
  # from earlier states.
  #
  class NeedSubmitCSR < KeySSLState; end

  # We have a CA bundle, optional CRL bundle, a private key and matching cert
  # that chains to one of the root certs in our bundle.
  #
  class Done < SSLState; end

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
