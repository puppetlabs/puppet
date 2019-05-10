require 'puppet/ssl'
require 'puppet/agent'

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
  include Puppet::Agent::Locker

  class SSLState
    attr_reader :ssl_context

    def initialize(machine, ssl_context)
      @machine = machine
      @ssl_context = ssl_context
      @cert_provider = Puppet::X509::CertProvider.new
      @ssl_provider = Puppet::SSL::SSLProvider.new
    end
  end

  # Load existing CA certs or download them. Transition to NeedCRLs.
  #
  class NeedCACerts < SSLState
    def initialize(machine)
      super(machine, nil)
      @ssl_context = @ssl_provider.create_insecure_context
    end

    def next_state
      Puppet.debug("Loading CA certs")

      cacerts = @cert_provider.load_cacerts
      if cacerts
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts, revocation: false)
      else
        pem = Puppet::Rest::Routes.get_certificate(Puppet::SSL::CA_NAME, @ssl_context)
        cacerts = @cert_provider.load_cacerts_from_pem(pem)
        # verify cacerts before saving
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts, revocation: false)
        @cert_provider.save_cacerts(cacerts)
      end

      NeedCRLs.new(@machine, next_ctx)
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 404
        raise Puppet::Error.new(_('CA certificate is missing from the server'))
      else
        raise Puppet::Error.new(_('Could not download CA certificate: %{message}') % { message: e.message }, e)
      end
    end
  end

  # If revocation is enabled, load CRLs or download them, using the CA bundle
  # from the previous state. Transition to NeedKey. Even if Puppet[:certificate_revocation]
  # is leaf or chain, disable revocation when downloading the CRL, since 1) we may
  # not have one yet or 2) the connection will fail if NeedCACerts downloaded a new CA
  # for which we don't have a CRL
  #
  class NeedCRLs < SSLState
    def next_state
      Puppet.debug("Loading CRLs")

      case Puppet[:certificate_revocation]
      when :chain, :leaf
        crls = @cert_provider.load_crls
        if crls
          next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: crls)

          crl_ttl = Puppet[:crl_refresh_interval]
          if crl_ttl
            last_update = @cert_provider.crl_last_update
            now = Time.now
            if last_update.nil? || now.to_i > last_update.to_i + crl_ttl
              # set last updated time first, then make a best effort to refresh
              @cert_provider.crl_last_update = now
              next_ctx = refresh_crl(next_ctx, last_update)
            end
          end
        else
          next_ctx = download_crl(@ssl_context, nil)
        end
      else
        Puppet.info("Certificate revocation is disabled, skipping CRL download")
        next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: [])
      end

      NeedKey.new(@machine, next_ctx)
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 404
        raise Puppet::Error.new(_('CRL is missing from the server'))
      else
        raise Puppet::Error.new(_('Could not download CRLs: %{message}') % { message: e.message }, e)
      end
    end

    private

    def refresh_crl(ssl_ctx, last_update)
      Puppet.info(_("Refreshing CRL"))

      # return the next_ctx containing the updated crl
      download_crl(ssl_ctx, last_update)
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 304
        Puppet.info(_("CRL is unmodified, using existing CRL"))
      else
        Puppet.info(_("Failed to refresh CRL, using existing CRL: %{message}") % {message: e.message})
      end

      # return the original ssl_ctx
      ssl_ctx
    rescue SystemCallError => e
      Puppet.warning(_("Failed to refresh CRL, using existing CRL: %{message}") % {message: e.message})

      # return the original ssl_ctx
      ssl_ctx
    end

    def download_crl(ssl_ctx, last_update)
      pem = Puppet::Rest::Routes.get_crls(Puppet::SSL::CA_NAME, ssl_ctx, if_modified_since: last_update)
      crls = @cert_provider.load_crls_from_pem(pem)
      # verify crls before saving
      next_ctx = @ssl_provider.create_root_context(cacerts: ssl_ctx[:cacerts], crls: crls)
      @cert_provider.save_crls(crls)

      next_ctx
    end
  end

  # Load or generate a private key. If the key exists, try to load the client cert
  # and transition to Done. If the cert is mismatched or otherwise fails valiation,
  # raise an error. If the key doesn't exist yet, generate one, and save it. If the
  # cert doesn't exist yet, transition to NeedSubmitCSR.
  #
  class NeedKey < SSLState
    def next_state
      Puppet.debug(_("Loading/generating private key"))

      password = @cert_provider.load_private_key_password
      key = @cert_provider.load_private_key(Puppet[:certname], password: password)
      if key
        cert = @cert_provider.load_client_cert(Puppet[:certname])
        if cert
          next_ctx = @ssl_provider.create_context(
            cacerts: @ssl_context.cacerts, crls: @ssl_context.crls, private_key: key, client_cert: cert
          )
          return Done.new(@machine, next_ctx)
        end
      else
        if Puppet[:key_type] == 'ec'
          Puppet.info _("Creating a new EC SSL key for %{name} using curve %{curve}") % { name: Puppet[:certname], curve: Puppet[:named_curve] }
          key = OpenSSL::PKey::EC.generate(Puppet[:named_curve])
        else
          Puppet.info _("Creating a new RSA SSL key for %{name}") % { name: Puppet[:certname] }
          key = OpenSSL::PKey::RSA.new(Puppet[:keylength].to_i)
        end

        @cert_provider.save_private_key(Puppet[:certname], key, password: password)
      end

      NeedSubmitCSR.new(@machine, @ssl_context, key)
    end
  end

  # Base class for states with a private key.
  #
  class KeySSLState < SSLState
    attr_reader :private_key

    def initialize(machine, ssl_context, private_key)
      super(machine, ssl_context)
      @private_key = private_key
    end
  end

  # Generate and submit a CSR using the CA cert bundle and optional CRL bundle
  # from earlier states. If the request is submitted, proceed to NeedCert,
  # otherwise Wait. This could be due to the server already having a CSR
  # for this host (either the same or different CSR content), having a
  # signed certificate, or a revoked certificate.
  #
  class NeedSubmitCSR < KeySSLState
    def next_state
      Puppet.debug(_("Generating and submitting a CSR"))

      csr = @cert_provider.create_request(Puppet[:certname], @private_key)
      Puppet::Rest::Routes.put_certificate_request(csr.to_pem, Puppet[:certname], @ssl_context)
      @cert_provider.save_request(Puppet[:certname], csr)
      NeedCert.new(@machine, @ssl_context, @private_key)
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i != 400
        raise Puppet::SSL::SSLError.new(_("Failed to submit the CSR, HTTP response was %{code}") % { code: e.response.code }, e)
      end

      NeedCert.new(@machine, @ssl_context, @private_key)
    end
  end

  # Attempt to load or retrieve our signed cert.
  #
  class NeedCert < KeySSLState
    def next_state
      Puppet.debug(_("Downloading client certificate"))

      cert = OpenSSL::X509::Certificate.new(
        Puppet::Rest::Routes.get_certificate(Puppet[:certname], @ssl_context)
      )
      # verify client cert before saving
      next_ctx = @ssl_provider.create_context(
        cacerts: @ssl_context.cacerts, crls: @ssl_context.crls, private_key: @private_key, client_cert: cert
      )
      @cert_provider.save_client_cert(Puppet[:certname], cert)
      @cert_provider.delete_request(Puppet[:certname])
      Done.new(@machine, next_ctx)
    rescue Puppet::SSL::SSLError => e
      Puppet.log_exception(e)
      Wait.new(@machine, @ssl_context)
    rescue OpenSSL::X509::CertificateError => e
      Puppet.log_exception(e, _("Failed to parse certificate: %{message}") % {message: e.message})
      Wait.new(@machine, @ssl_context)
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 404
        Puppet.info(_("Certificate for %{certname} has not been signed yet") % {certname: Puppet[:certname]})
      else
        Puppet.log_exception(e, _("Failed to retrieve certificate for %{certname}: %{message}") %
                             {certname: Puppet[:certname], message: e.response.message})
      end
      Wait.new(@machine, @ssl_context)
    end
  end

  # We cannot make progress, so wait if allowed to do so, or error.
  #
  class Wait < SSLState
    def next_state
      time = @machine.waitforcert
      if time < 1
        puts _("Couldn't fetch certificate from CA server; you might still need to sign this agent's certificate (%{name}). Exiting now because the waitforcert setting is set to 0.") % { name: Puppet[:certname] }
        exit(1)
      elsif Time.now.to_i > @machine.wait_deadline
        puts _("Couldn't fetch certificate from CA server; you might still need to sign this agent's certificate (%{name}). Exiting now because the maxwaitforcert timeout has been exceeded.") % {name: Puppet[:certname] }
        exit(1)
      else
        Puppet.info(_("Couldn't fetch certificate from CA server; you might still need to sign this agent's certificate (%{name}). Will try again in %{time} seconds.") % {name: Puppet[:certname], time: time})

        sleep(time)

        # our ssl directory may have been cleaned while we were
        # sleeping, start over from the top
        NeedCACerts.new(@machine)
      end
    end
  end

  # We have a CA bundle, optional CRL bundle, a private key and matching cert
  # that chains to one of the root certs in our bundle.
  #
  class Done < SSLState; end

  attr_reader :waitforcert, :wait_deadline

  def initialize(waitforcert: Puppet[:waitforcert], maxwaitforcert: Puppet[:maxwaitforcert])
    @waitforcert = waitforcert
    @wait_deadline = Time.now.to_i + maxwaitforcert
  end

  # Run the state machine for CA certs and CRLs
  #
  # @return [Puppet::SSL::SSLContext] initialized SSLContext
  def ensure_ca_certificates
    final_state = run_machine(NeedCACerts.new(self), NeedKey)
    final_state.ssl_context
  end

  # Run the state machine for CA certs and CRLs
  #
  # @return [Puppet::SSL::SSLContext] initialized SSLContext
  def ensure_client_certificate
    final_state = run_machine(NeedCACerts.new(self), Done)
    ssl_context = final_state.ssl_context

    if Puppet::Util::Log.sendlevel?(:debug)
      chain = ssl_context.client_chain
      # print from root to client
      chain.reverse.each_with_index do |cert, i|
        digest = Puppet::SSL::Digest.new('SHA256', cert.to_der)
        if i == chain.length - 1
          Puppet.debug(_("Verified client certificate '%{subject}' fingerprint %{digest}") % {subject: cert.subject.to_utf8, digest: digest})
        else
          Puppet.debug(_("Verified CA certificate '%{subject}' fingerprint %{digest}") % {subject: cert.subject.to_utf8, digest: digest})
        end
      end
    end

    ssl_context
  end

  private

  def run_machine(state, stop)
    lock do
      loop do
        state = state.next_state

        break if state.is_a?(stop)
      end
    end

    state
  rescue Puppet::LockError
    raise Puppet::Error, 'Another puppet instance is already running; exiting'
  end
end
