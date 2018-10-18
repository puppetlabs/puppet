require 'puppet/application'
require 'puppet/ssl/oids'

class Puppet::Application::Ssl < Puppet::Application

  run_mode :agent

  def summary
    _("Manage SSL keys and certificates for puppet SSL clients")
  end

  def help
    <<-HELP
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
  Print this help messsge.

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

* submit_request:
  Generate a certificate signing request (CSR) and submit it to the CA. If
  a private and public key pair already exist, they will be used to generate
  the CSR. Otherwise a new key pair will be generated. If a CSR has already
  been submitted with the given `certname`, then the operation will fail.

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
HELP
  end

  option('--target CERTNAME') do |arg|
    options[:target] = arg.to_s
  end
  option('--localca')
  option('--verbose', '-v')
  option('--debug', '-d')

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
      host = Puppet::SSL::Host.new(Puppet[:certname], true)
      Puppet.settings.use(:main, :agent, :device)
    else
      host = Puppet::SSL::Host.new(Puppet[:certname])
      Puppet.settings.use(:main, :agent)
    end

    action = command_line.args.first
    case action
    when 'submit_request'
      submit_request(host)
      cert = download_cert(host)
      unless cert
        Puppet.info _("The certificate for '%{name}' has not yet been signed") % { name: host.name }
      end
    when 'download_cert'
      cert = download_cert(host)
      unless cert
        raise Puppet::Error, _("The certificate for '%{name}' has not yet been signed") % { name: host.name }
      end
    when 'verify'
      verify(host)
    when 'clean'
      clean(host)
    else
      raise Puppet::Error, _("Unknown action '%{action}'") % { action: action }
    end
  end

  def submit_request(host)
    host.ensure_ca_certificate

    host.submit_request
    Puppet.notice _("Submitted certificate request for '%{name}' to https://%{server}:%{port}") % {
      name: host.name, server: Puppet[:ca_server], port: Puppet[:ca_port]
    }
  rescue => e
    raise Puppet::Error.new(_("Failed to submit certificate request: %{message}") % { message: e.message }, e)
  end

  def download_cert(host)
    host.ensure_ca_certificate

    Puppet.info _("Downloading certificate '%{name}' from https://%{server}:%{port}") % {
      name: host.name, server: Puppet[:ca_server], port: Puppet[:ca_port]
    }
    cert = host.download_host_certificate
    return unless cert

    Puppet.notice _("Downloaded certificate '%{name}' with fingerprint %{fingerprint}") % {
      name: host.name, fingerprint: cert.fingerprint
    }
    cert
  rescue => e
    raise Puppet::Error.new(_("Failed to download certificate: %{message}") % { message: e.message }, e)
  end

  def verify(host)
    host.ensure_ca_certificate

    key = host.key
    raise _("The host's private key is missing") unless key

    cert = host.check_for_certificate_on_disk(host.name)
    raise _("The host's certificate is missing") unless cert

    if cert.content.public_key.to_pem != key.content.public_key.to_pem
      raise _("The host's key does not match the certificate")
    end

    store = host.ssl_store
    unless store.verify(cert.content)
      raise _("Failed to verify certificate '%{name}': %{message} (%{error})") % {
        name: host.name, message: store.error_string, error: store.error
      }
    end

    Puppet.notice _("Verified certificate '%{name}'") % {
      name: host.name
    }
    # store.chain.reverse.each_with_index do |issuer, i|
    #   indent = "  " * (i+1)
    #   Puppet.notice "#{indent}#{issuer.subject.to_s}"
    # end
  rescue => e
    raise Puppet::Error.new(_("Verify failed: %{message}") % { message: e.message }, e)
  end

  def clean(host)
    # make sure cert has been removed from the CA
    if host.name == Puppet[:ca_server]
      cert =
        begin
          host.download_certificate_from_ca(host.name)
        rescue => e
          raise Puppet::Error.new(_("Failed to connect to the CA to determine if certificate %{certname} has been cleaned") % { certname: host.name }, e)
        end

      if cert
        raise Puppet::Error, _(<<END) % { certname: host.name }
The certificate %{certname} must be cleaned from the CA first. To fix this,
run the following commands on the CA:
  puppetserver ca clean --certname %{certname}
  puppet ssl clean
END
      end
    end

    settings = {
      hostprivkey: 'private key',
      hostpubkey: 'public key',
      hostcsr: 'certificate request',
      hostcert: 'certificate',
      passfile: 'private key password file'
    }
    settings.merge!(localcacert: 'local CA certificate', hostcrl: 'local CRL') if options[:localca]
    settings.each_pair do |setting, label|
      path = Puppet[setting]
      if Puppet::FileSystem.exist?(path)
        Puppet::FileSystem.unlink(path)
        Puppet.notice _("Removed %{label} %{path}") % { label: label, path: path }
      end
    end
  end
end
