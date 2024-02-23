# frozen_string_literal: true

require_relative '../../puppet/application'
require_relative '../../puppet/ssl/oids'

class Puppet::Application::Ssl < Puppet::Application
  run_mode :agent

  def summary
    _("Manage SSL keys and certificates for puppet SSL clients")
  end

  def help
    <<~HELP
      puppet-ssl(8) -- #{summary}
      ========

      SYNOPSIS
      --------
      Manage SSL keys and certificates for SSL clients needing
      to communicate with a puppet infrastructure.

      USAGE
      -----
      puppet ssl <action> [-h|--help] [-v|--verbose] [-d|--debug] [--localca] [--target CERTNAME]


      OPTIONS
      -------

      * --help:
        Print this help message.

      * --verbose:
        Print extra information.

      * --debug:
        Enable full debugging.

      * --localca
        Also clean the local CA certificate and CRL.

      * --target CERTNAME
        Clean the specified device certificate instead of this host's certificate.

      ACTIONS
      -------

      * bootstrap:
        Perform all of the steps necessary to request and download a client
        certificate. If autosigning is disabled, then puppet will wait every
        `waitforcert` seconds for its certificate to be signed. To only attempt
        once and never wait, specify a time of 0. Since `waitforcert` is a
        Puppet setting, it can be specified as a time interval, such as 30s,
        5m, 1h.

      * submit_request:
        Generate a certificate signing request (CSR) and submit it to the CA. If
        a private and public key pair already exist, they will be used to generate
        the CSR. Otherwise a new key pair will be generated. If a CSR has already
        been submitted with the given `certname`, then the operation will fail.

      * generate_request:
        Generate a certificate signing request (CSR). If
        a private and public key pair already exist, they will be used to generate
        the CSR. Otherwise a new key pair will be generated.

      * download_cert:
        Download a certificate for this host. If the current private key matches
        the downloaded certificate, then the certificate will be saved and used
        for subsequent requests. If there is already an existing certificate, it
        will be overwritten.

      * verify:
        Verify the private key and certificate are present and match, verify the
        certificate is issued by a trusted CA, and check revocation status.

      * clean:
        Remove the private key and certificate related files for this host. If
        `--localca` is specified, then also remove this host's local copy of the
        CA certificate(s) and CRL bundle. if `--target CERTNAME` is specified, then
        remove the files for the specified device on this host instead of this host.

       * show:
        Print the full-text version of this host's certificate.
    HELP
  end

  option('--target CERTNAME') do |arg|
    options[:target] = arg.to_s
  end
  option('--localca')
  option('--verbose', '-v')
  option('--debug', '-d')

  def initialize(command_line = Puppet::Util::CommandLine.new)
    super(command_line)

    @cert_provider = Puppet::X509::CertProvider.new
    @ssl_provider = Puppet::SSL::SSLProvider.new
    @machine = Puppet::SSL::StateMachine.new
    @session = Puppet.runtime[:http].create_session
  end

  def setup_logs
    set_log_level(options)
    Puppet::Util::Log.newdestination(:console)
  end

  def main
    if command_line.args.empty?
      raise Puppet::Error, _("An action must be specified.")
    end

    if options[:target]
      # Override the following, as per lib/puppet/application/device.rb
      Puppet[:certname] = options[:target]
      Puppet[:confdir]  = File.join(Puppet[:devicedir], Puppet[:certname])
      Puppet[:vardir]   = File.join(Puppet[:devicedir], Puppet[:certname])
      Puppet.settings.use(:main, :agent, :device)
    else
      Puppet.settings.use(:main, :agent)
    end

    Puppet::SSL::Oids.register_puppet_oids
    Puppet::SSL::Oids.load_custom_oid_file(Puppet[:trusted_oid_mapping_file])

    certname = Puppet[:certname]
    action = command_line.args.first
    case action
    when 'submit_request'
      ssl_context = @machine.ensure_ca_certificates
      if submit_request(ssl_context)
        cert = download_cert(ssl_context)
        unless cert
          Puppet.info(_("The certificate for '%{name}' has not yet been signed") % { name: certname })
        end
      end
    when 'download_cert'
      ssl_context = @machine.ensure_ca_certificates
      cert = download_cert(ssl_context)
      unless cert
        raise Puppet::Error, _("The certificate for '%{name}' has not yet been signed") % { name: certname }
      end
    when 'generate_request'
      generate_request(certname)
    when 'verify'
      verify(certname)
    when 'clean'
      possible_extra_args = command_line.args.drop(1)
      unless possible_extra_args.empty?
        raise Puppet::Error, _(<<~END) % { args: possible_extra_args.join(' ') }
          Extra arguments detected: %{args}
          Did you mean to run:
            puppetserver ca clean --certname <name>
          Or:
            puppet ssl clean --target <name>
        END
      end

      clean(certname)
    when 'bootstrap'
      unless Puppet::Util::Log.sendlevel?(:info)
        Puppet::Util::Log.level = :info
      end
      @machine.ensure_client_certificate
      Puppet.notice(_("Completed SSL initialization"))
    when 'show'
      show(certname)
    else
      raise Puppet::Error, _("Unknown action '%{action}'") % { action: action }
    end
  end

  def show(certname)
    password = @cert_provider.load_private_key_password
    ssl_context = @ssl_provider.load_context(certname: certname, password: password)
    puts ssl_context.client_cert.to_text
  end

  def submit_request(ssl_context)
    key = @cert_provider.load_private_key(Puppet[:certname])
    unless key
      key = create_key(Puppet[:certname])
      @cert_provider.save_private_key(Puppet[:certname], key)
    end

    csr = @cert_provider.create_request(Puppet[:certname], key)
    route = create_route(ssl_context)
    route.put_certificate_request(Puppet[:certname], csr, ssl_context: ssl_context)
    @cert_provider.save_request(Puppet[:certname], csr)
    Puppet.notice _("Submitted certificate request for '%{name}' to %{url}") % { name: Puppet[:certname], url: route.url }
  rescue Puppet::HTTP::ResponseError => e
    if e.response.code == 400
      raise Puppet::Error.new(_("Could not submit certificate request for '%{name}' to %{url} due to a conflict on the server") % { name: Puppet[:certname], url: route.url })
    else
      raise Puppet::Error.new(_("Failed to submit certificate request: %{message}") % { message: e.message }, e)
    end
  rescue => e
    raise Puppet::Error.new(_("Failed to submit certificate request: %{message}") % { message: e.message }, e)
  end

  def generate_request(certname)
    key = @cert_provider.load_private_key(certname)
    unless key
      key = create_key(certname)
      @cert_provider.save_private_key(certname, key)
    end

    csr = @cert_provider.create_request(certname, key)
    @cert_provider.save_request(certname, csr)
    Puppet.notice _("Generated certificate request in '%{path}'") % { path: @cert_provider.to_path(Puppet[:requestdir], certname) }
  rescue => e
    raise Puppet::Error.new(_("Failed to generate certificate request: %{message}") % { message: e.message }, e)
  end

  def download_cert(ssl_context)
    key = @cert_provider.load_private_key(Puppet[:certname])

    # try to download cert
    route = create_route(ssl_context)
    Puppet.info _("Downloading certificate '%{name}' from %{url}") % { name: Puppet[:certname], url: route.url }

    _, x509 = route.get_certificate(Puppet[:certname], ssl_context: ssl_context)
    cert = OpenSSL::X509::Certificate.new(x509)
    Puppet.notice _("Downloaded certificate '%{name}' with fingerprint %{fingerprint}") % { name: Puppet[:certname], fingerprint: fingerprint(cert) }

    # verify client cert before saving
    @ssl_provider.create_context(
      cacerts: ssl_context.cacerts, crls: ssl_context.crls, private_key: key, client_cert: cert
    )
    @cert_provider.save_client_cert(Puppet[:certname], cert)
    @cert_provider.delete_request(Puppet[:certname])
    cert
  rescue Puppet::HTTP::ResponseError => e
    if e.response.code == 404
      return nil
    else
      raise Puppet::Error.new(_("Failed to download certificate: %{message}") % { message: e.message }, e)
    end
  rescue => e
    raise Puppet::Error.new(_("Failed to download certificate: %{message}") % { message: e.message }, e)
  end

  def verify(certname)
    password = @cert_provider.load_private_key_password
    ssl_context = @ssl_provider.load_context(certname: certname, password: password)

    # print from root to client
    ssl_context.client_chain.reverse.each_with_index do |cert, i|
      digest = Puppet::SSL::Digest.new('SHA256', cert.to_der)
      if i == ssl_context.client_chain.length - 1
        Puppet.notice("Verified client certificate '#{cert.subject.to_utf8}' fingerprint #{digest}")
      else
        Puppet.notice("Verified CA certificate '#{cert.subject.to_utf8}' fingerprint #{digest}")
      end
    end
  end

  def clean(certname)
    # make sure cert has been removed from the CA
    if certname == Puppet[:ca_server]
      cert = nil

      begin
        ssl_context = @machine.ensure_ca_certificates
        route = create_route(ssl_context)
        _, cert = route.get_certificate(certname, ssl_context: ssl_context)
      rescue Puppet::HTTP::ResponseError => e
        if e.response.code.to_i != 404
          raise Puppet::Error.new(_("Failed to connect to the CA to determine if certificate %{certname} has been cleaned") % { certname: certname }, e)
        end
      rescue => e
        raise Puppet::Error.new(_("Failed to connect to the CA to determine if certificate %{certname} has been cleaned") % { certname: certname }, e)
      end

      if cert
        raise Puppet::Error, _(<<~END) % { certname: certname }
          The certificate %{certname} must be cleaned from the CA first. To fix this,
          run the following commands on the CA:
            puppetserver ca clean --certname %{certname}
            puppet ssl clean
        END
      end
    end

    paths = {
      'private key' => Puppet[:hostprivkey],
      'public key' => Puppet[:hostpubkey],
      'certificate request' => Puppet[:hostcsr],
      'certificate' => Puppet[:hostcert],
      'private key password file' => Puppet[:passfile]
    }
    if options[:localca]
      paths['local CA certificate'] = Puppet[:localcacert]
      paths['local CRL'] = Puppet[:hostcrl]
    end
    paths.each_pair do |label, path|
      if Puppet::FileSystem.exist?(path)
        Puppet::FileSystem.unlink(path)
        Puppet.notice _("Removed %{label} %{path}") % { label: label, path: path }
      end
    end
  end

  private

  def fingerprint(cert)
    Puppet::SSL::Digest.new(nil, cert.to_der)
  end

  def create_route(ssl_context)
    @session.route_to(:ca, ssl_context: ssl_context)
  end

  def create_key(certname)
    if Puppet[:key_type] == 'ec'
      Puppet.info _("Creating a new EC SSL key for %{name} using curve %{curve}") % { name: certname, curve: Puppet[:named_curve] }
      OpenSSL::PKey::EC.generate(Puppet[:named_curve])
    else
      Puppet.info _("Creating a new SSL key for %{name}") % { name: certname }
      OpenSSL::PKey::RSA.new(Puppet[:keylength].to_i)
    end
  end
end
