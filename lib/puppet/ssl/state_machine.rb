# frozen_string_literal: true

require_relative '../../puppet/ssl'
require_relative '../../puppet/util/pidlock'

# This class implements a state machine for bootstrapping a host's CA and CRL
# bundles, private key and signed client certificate. Each state has a frozen
# SSLContext that it uses to make network connections. If a state makes progress
# bootstrapping the host, then the state will generate a new frozen SSLContext
# and pass that to the next state. For example, the NeedCACerts state will load
# or download a CA bundle, and generate a new SSLContext containing those CA
# certs. This way we're sure about which SSLContext is being used during any
# phase of the bootstrapping process.
#
# @api private
class Puppet::SSL::StateMachine
  class SSLState
    attr_reader :ssl_context

    def initialize(machine, ssl_context)
      @machine = machine
      @ssl_context = ssl_context
      @cert_provider = machine.cert_provider
      @ssl_provider = machine.ssl_provider
    end

    def to_error(message, cause)
      detail = Puppet::Error.new(message)
      detail.set_backtrace(cause.backtrace)
      Error.new(@machine, message, detail)
    end

    def log_error(message)
      # When running daemonized we set stdout to /dev/null, so write to the log instead
      if Puppet[:daemonize]
        Puppet.err(message)
      else
        $stdout.puts(message)
      end
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

      force_crl_refresh = false

      cacerts = @cert_provider.load_cacerts
      if cacerts
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts, revocation: false)

        now = Time.now
        last_update = @cert_provider.ca_last_update
        if needs_refresh?(now, last_update)
          # If we refresh the CA, then we need to force the CRL to be refreshed too,
          # since if there is a new CA in the chain, then we need its CRL to check
          # the full chain for revocation status.
          next_ctx, force_crl_refresh = refresh_ca(next_ctx, last_update)
        end
      else
        route = @machine.session.route_to(:ca, ssl_context: @ssl_context)
        _, pem = route.get_certificate(Puppet::SSL::CA_NAME, ssl_context: @ssl_context)
        if @machine.ca_fingerprint
          actual_digest = @machine.digest_as_hex(pem)
          expected_digest = @machine.ca_fingerprint.scan(/../).join(':').upcase
          if actual_digest == expected_digest
            Puppet.info(_("Verified CA bundle with digest (%{digest_type}) %{actual_digest}") %
                        { digest_type: @machine.digest, actual_digest: actual_digest })
          else
            e = Puppet::Error.new(_("CA bundle with digest (%{digest_type}) %{actual_digest} did not match expected digest %{expected_digest}") % { digest_type: @machine.digest, actual_digest: actual_digest, expected_digest: expected_digest })
            return Error.new(@machine, e.message, e)
          end
        end

        cacerts = @cert_provider.load_cacerts_from_pem(pem)
        # verify cacerts before saving
        next_ctx = @ssl_provider.create_root_context(cacerts: cacerts, revocation: false)
        @cert_provider.save_cacerts(cacerts)
      end

      NeedCRLs.new(@machine, next_ctx, force_crl_refresh)
    rescue OpenSSL::X509::CertificateError => e
      Error.new(@machine, e.message, e)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 404
        to_error(_('CA certificate is missing from the server'), e)
      else
        to_error(_('Could not download CA certificate: %{message}') % { message: e.message }, e)
      end
    end

    private

    def needs_refresh?(now, last_update)
      return true if last_update.nil?

      ca_ttl = Puppet[:ca_refresh_interval]
      return false unless ca_ttl

      now.to_i > last_update.to_i + ca_ttl
    end

    def refresh_ca(ssl_ctx, last_update)
      Puppet.info(_("Refreshing CA certificate"))

      # return the next_ctx containing the updated ca
      next_ctx = [download_ca(ssl_ctx, last_update), true]

      # After a successful refresh, update ca_last_update
      @cert_provider.ca_last_update = Time.now

      next_ctx
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 304
        Puppet.info(_("CA certificate is unmodified, using existing CA certificate"))
      else
        Puppet.info(_("Failed to refresh CA certificate, using existing CA certificate: %{message}") % { message: e.message })
      end

      # return the original ssl_ctx
      [ssl_ctx, false]
    rescue Puppet::HTTP::HTTPError => e
      Puppet.warning(_("Failed to refresh CA certificate, using existing CA certificate: %{message}") % { message: e.message })

      # return the original ssl_ctx
      [ssl_ctx, false]
    end

    def download_ca(ssl_ctx, last_update)
      route = @machine.session.route_to(:ca, ssl_context: ssl_ctx)
      _, pem = route.get_certificate(Puppet::SSL::CA_NAME, if_modified_since: last_update, ssl_context: ssl_ctx)
      cacerts = @cert_provider.load_cacerts_from_pem(pem)
      # verify cacerts before saving
      next_ctx = @ssl_provider.create_root_context(cacerts: cacerts, revocation: false)
      @cert_provider.save_cacerts(cacerts)

      Puppet.info("Refreshed CA certificate: #{@machine.digest_as_hex(pem)}")

      next_ctx
    end
  end

  # If revocation is enabled, load CRLs or download them, using the CA bundle
  # from the previous state. Transition to NeedKey. Even if Puppet[:certificate_revocation]
  # is leaf or chain, disable revocation when downloading the CRL, since 1) we may
  # not have one yet or 2) the connection will fail if NeedCACerts downloaded a new CA
  # for which we don't have a CRL
  #
  class NeedCRLs < SSLState
    attr_reader :force_crl_refresh

    def initialize(machine, ssl_context, force_crl_refresh = false)
      super(machine, ssl_context)
      @force_crl_refresh = force_crl_refresh
    end

    def next_state
      Puppet.debug("Loading CRLs")

      case Puppet[:certificate_revocation]
      when :chain, :leaf
        crls = @cert_provider.load_crls
        if crls
          next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: crls)

          now = Time.now
          last_update = @cert_provider.crl_last_update
          if needs_refresh?(now, last_update)
            next_ctx = refresh_crl(next_ctx, last_update)
          end
        else
          next_ctx = download_crl(@ssl_context, nil)
        end
      else
        Puppet.info("Certificate revocation is disabled, skipping CRL download")
        next_ctx = @ssl_provider.create_root_context(cacerts: ssl_context[:cacerts], crls: [])
      end

      NeedKey.new(@machine, next_ctx)
    rescue OpenSSL::X509::CRLError => e
      Error.new(@machine, e.message, e)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 404
        to_error(_('CRL is missing from the server'), e)
      else
        to_error(_('Could not download CRLs: %{message}') % { message: e.message }, e)
      end
    end

    private

    def needs_refresh?(now, last_update)
      return true if @force_crl_refresh || last_update.nil?

      crl_ttl = Puppet[:crl_refresh_interval]
      return false unless crl_ttl

      now.to_i > last_update.to_i + crl_ttl
    end

    def refresh_crl(ssl_ctx, last_update)
      Puppet.info(_("Refreshing CRL"))

      # return the next_ctx containing the updated crl
      next_ctx = download_crl(ssl_ctx, last_update)

      # After a successful refresh, update crl_last_update
      @cert_provider.crl_last_update = Time.now

      next_ctx
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 304
        Puppet.info(_("CRL is unmodified, using existing CRL"))
      else
        Puppet.info(_("Failed to refresh CRL, using existing CRL: %{message}") % { message: e.message })
      end

      # return the original ssl_ctx
      ssl_ctx
    rescue Puppet::HTTP::HTTPError => e
      Puppet.warning(_("Failed to refresh CRL, using existing CRL: %{message}") % { message: e.message })

      # return the original ssl_ctx
      ssl_ctx
    end

    def download_crl(ssl_ctx, last_update)
      route = @machine.session.route_to(:ca, ssl_context: ssl_ctx)
      _, pem = route.get_certificate_revocation_list(if_modified_since: last_update, ssl_context: ssl_ctx)
      crls = @cert_provider.load_crls_from_pem(pem)
      # verify crls before saving
      next_ctx = @ssl_provider.create_root_context(cacerts: ssl_ctx[:cacerts], crls: crls)
      @cert_provider.save_crls(crls)

      Puppet.info("Refreshed CRL: #{@machine.digest_as_hex(pem)}")

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
          if needs_refresh?(cert)
            return NeedRenewedCert.new(@machine, next_ctx, key)
          else
            return Done.new(@machine, next_ctx)
          end
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

    private

    def needs_refresh?(cert)
      cert_ttl = Puppet[:hostcert_renewal_interval]
      return false unless cert_ttl

      Time.now.to_i >= (cert.not_after.to_i - cert_ttl)
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
      route = @machine.session.route_to(:ca, ssl_context: @ssl_context)
      route.put_certificate_request(Puppet[:certname], csr, ssl_context: @ssl_context)
      @cert_provider.save_request(Puppet[:certname], csr)
      NeedCert.new(@machine, @ssl_context, @private_key)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 400
        NeedCert.new(@machine, @ssl_context, @private_key)
      else
        to_error(_("Failed to submit the CSR, HTTP response was %{code}") % { code: e.response.code }, e)
      end
    end
  end

  # Attempt to load or retrieve our signed cert.
  #
  class NeedCert < KeySSLState
    def next_state
      Puppet.debug(_("Downloading client certificate"))

      route = @machine.session.route_to(:ca, ssl_context: @ssl_context)
      cert = OpenSSL::X509::Certificate.new(
        route.get_certificate(Puppet[:certname], ssl_context: @ssl_context)[1]
      )
      Puppet.info _("Downloaded certificate for %{name} from %{url}") % { name: Puppet[:certname], url: route.url }
      # verify client cert before saving
      next_ctx = @ssl_provider.create_context(
        cacerts: @ssl_context.cacerts, crls: @ssl_context.crls, private_key: @private_key, client_cert: cert
      )
      @cert_provider.save_client_cert(Puppet[:certname], cert)
      @cert_provider.delete_request(Puppet[:certname])
      Done.new(@machine, next_ctx)
    rescue Puppet::SSL::SSLError => e
      Error.new(@machine, e.message, e)
    rescue OpenSSL::X509::CertificateError => e
      Error.new(@machine, _("Failed to parse certificate: %{message}") % { message: e.message }, e)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 404
        Puppet.info(_("Certificate for %{certname} has not been signed yet") % { certname: Puppet[:certname] })
        $stdout.puts _("Couldn't fetch certificate from CA server; you might still need to sign this agent's certificate (%{name}).") % { name: Puppet[:certname] }
        Wait.new(@machine)
      else
        to_error(_("Failed to retrieve certificate for %{certname}: %{message}") %
                 { certname: Puppet[:certname], message: e.message }, e)
      end
    end
  end

  # Class to renew a client/host certificate automatically.
  #
  class NeedRenewedCert < KeySSLState
    def next_state
      Puppet.debug(_("Renewing client certificate"))

      route = @machine.session.route_to(:ca, ssl_context: @ssl_context)
      cert = OpenSSL::X509::Certificate.new(
        route.post_certificate_renewal(@ssl_context)[1]
      )

      # verify client cert before saving
      next_ctx = @ssl_provider.create_context(
        cacerts: @ssl_context.cacerts, crls: @ssl_context.crls, private_key: @private_key, client_cert: cert
      )
      @cert_provider.save_client_cert(Puppet[:certname], cert)

      Puppet.info(_("Renewed client certificate: %{cert_digest}, not before '%{not_before}', not after '%{not_after}'") % { cert_digest: @machine.digest_as_hex(cert.to_pem), not_before: cert.not_before, not_after: cert.not_after })

      Done.new(@machine, next_ctx)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 404
        Puppet.info(_("Certificate autorenewal has not been enabled on the server."))
      else
        Puppet.warning(_("Failed to automatically renew certificate: %{code} %{reason}") % { code: e.response.code, reason: e.response.reason })
      end
      Done.new(@machine, @ssl_context)
    rescue => e
      Puppet.warning(_("Unable to automatically renew certificate: %{message}") % { message: e.message })
      Done.new(@machine, @ssl_context)
    end
  end

  # We cannot make progress, so wait if allowed to do so, or exit.
  #
  class Wait < SSLState
    def initialize(machine)
      super(machine, nil)
    end

    def next_state
      time = @machine.waitforcert
      if time < 1
        log_error(_("Exiting now because the waitforcert setting is set to 0."))
        exit(1)
      elsif Time.now.to_i > @machine.wait_deadline
        log_error(_("Couldn't fetch certificate from CA server; you might still need to sign this agent's certificate (%{name}). Exiting now because the maxwaitforcert timeout has been exceeded.") % { name: Puppet[:certname] })
        exit(1)
      else
        Puppet.info(_("Will try again in %{time} seconds.") % { time: time })

        # close http/tls and session state before sleeping
        Puppet.runtime[:http].close
        @machine.session = Puppet.runtime[:http].create_session

        @machine.unlock
        Kernel.sleep(time)
        NeedLock.new(@machine)
      end
    end
  end

  # Acquire the ssl lock or return LockFailure causing us to exit.
  #
  class NeedLock < SSLState
    def initialize(machine)
      super(machine, nil)
    end

    def next_state
      if @machine.lock
        # our ssl directory may have been cleaned while we were
        # sleeping, start over from the top
        NeedCACerts.new(@machine)
      elsif @machine.waitforlock < 1
        LockFailure.new(@machine, _("Another puppet instance is already running and the waitforlock setting is set to 0; exiting"))
      elsif Time.now.to_i >= @machine.waitlock_deadline
        LockFailure.new(@machine, _("Another puppet instance is already running and the maxwaitforlock timeout has been exceeded; exiting"))
      else
        Puppet.info _("Another puppet instance is already running; waiting for it to finish")
        Puppet.info _("Will try again in %{time} seconds.") % { time: @machine.waitforlock }
        Kernel.sleep @machine.waitforlock

        # try again
        self
      end
    end
  end

  # We failed to acquire the lock, so exit
  #
  class LockFailure < SSLState
    attr_reader :message

    def initialize(machine, message)
      super(machine, nil)
      @message = message
    end
  end

  # We cannot make progress due to an error.
  #
  class Error < SSLState
    attr_reader :message, :error

    def initialize(machine, message, error)
      super(machine, nil)
      @message = message
      @error = error
    end

    def next_state
      Puppet.log_exception(@error, @message)
      Wait.new(@machine)
    end
  end

  # We have a CA bundle, optional CRL bundle, a private key and matching cert
  # that chains to one of the root certs in our bundle.
  #
  class Done < SSLState; end

  attr_reader :waitforcert, :wait_deadline, :waitforlock, :waitlock_deadline, :cert_provider, :ssl_provider, :ca_fingerprint, :digest
  attr_accessor :session

  # Construct a state machine to manage the SSL initialization process. By
  # default, if the state machine encounters an exception, it will log the
  # exception and wait for `waitforcert` seconds and retry, restarting from the
  # beginning of the state machine.
  #
  # However, if `onetime` is true, then the state machine will raise the first
  # error it encounters, instead of waiting. Otherwise, if `waitforcert` is 0,
  # then then state machine will exit instead of wait.
  #
  # @param waitforcert [Integer] how many seconds to wait between attempts
  # @param maxwaitforcert [Integer] maximum amount of seconds to wait for the
  #   server to sign the certificate request
  # @param waitforlock [Integer] how many seconds to wait between attempts for
  #   acquiring the ssl lock
  # @param maxwaitforlock [Integer] maximum amount of seconds to wait for an
  #   already running process to release the ssl lock
  # @param onetime [Boolean] whether to run onetime
  # @param lockfile [Puppet::Util::Pidlock] lockfile to protect against
  #   concurrent modification by multiple processes
  # @param cert_provider [Puppet::X509::CertProvider] cert provider to use
  #   to load and save X509 objects.
  # @param ssl_provider [Puppet::SSL::SSLProvider] ssl provider to use
  #   to construct ssl contexts.
  # @param digest [String] digest algorithm to use for certificate fingerprinting
  # @param ca_fingerprint [String] optional fingerprint to verify the
  #   downloaded CA bundle
  def initialize(waitforcert: Puppet[:waitforcert],
                 maxwaitforcert: Puppet[:maxwaitforcert],
                 waitforlock: Puppet[:waitforlock],
                 maxwaitforlock: Puppet[:maxwaitforlock],
                 onetime: Puppet[:onetime],
                 cert_provider: Puppet::X509::CertProvider.new,
                 ssl_provider: Puppet::SSL::SSLProvider.new,
                 lockfile: Puppet::Util::Pidlock.new(Puppet[:ssl_lockfile]),
                 digest: 'SHA256',
                 ca_fingerprint: Puppet[:ca_fingerprint])
    @waitforcert = waitforcert
    @wait_deadline = Time.now.to_i + maxwaitforcert
    @waitforlock = waitforlock
    @waitlock_deadline = Time.now.to_i + maxwaitforlock
    @onetime = onetime
    @cert_provider = cert_provider
    @ssl_provider = ssl_provider
    @lockfile = lockfile
    @digest = digest
    @ca_fingerprint = ca_fingerprint
    @session = Puppet.runtime[:http].create_session
  end

  # Run the state machine for CA certs and CRLs.
  #
  # @return [Puppet::SSL::SSLContext] initialized SSLContext
  # @raise [Puppet::Error] If we fail to generate an SSLContext
  # @api private
  def ensure_ca_certificates
    final_state = run_machine(NeedLock.new(self), NeedKey)
    final_state.ssl_context
  end

  # Run the state machine for client certs.
  #
  # @return [Puppet::SSL::SSLContext] initialized SSLContext
  # @raise [Puppet::Error] If we fail to generate an SSLContext
  # @api private
  def ensure_client_certificate
    final_state = run_machine(NeedLock.new(self), Done)
    ssl_context = final_state.ssl_context
    @ssl_provider.print(ssl_context, @digest)
    ssl_context
  end

  def lock
    @lockfile.lock
  end

  def unlock
    @lockfile.unlock
  end

  def digest_as_hex(str)
    Puppet::SSL::Digest.new(digest, str).to_hex
  end

  private

  def run_machine(state, stop)
    loop do
      state = run_step(state)

      case state
      when stop
        break
      when LockFailure
        raise Puppet::Error, state.message
      when Error
        if @onetime
          Puppet.log_exception(state.error)
          raise state.error
        end
      else
        # fall through
      end
    end

    state
  ensure
    @lockfile.unlock if @lockfile.locked?
  end

  def run_step(state)
    state.next_state
  rescue => e
    state.to_error(e.message, e)
  end
end
