require 'puppet/application'
require 'puppet/ssl/oids'

class Puppet::Application::Ssl < Puppet::Application
  def summary
    _("Manage SSL keys and certificates for puppet SSL clients")
  end

  def help
    <<-HELP
puppet-ssl(8) -- #{summary}
========

SYNOPSIS
--------
Manage SSL keys and certificates for an SSL clients needed
to communicate with a puppet infrastructure.

USAGE
-----
puppet ssl <action> [--certname <NAME>]

ACTIONS
-------

* submit_request:
  Generate a certificate signing request (CSR) and submit it to the CA. If a private and
  public key pair already exist, they will be used to generate the CSR. Otherwise a new
  key pair will be generated. If a CSR has already been submitted with the given `certname`,
  then the operation will fail.

* download_cert:
  Download a certificate for this host. If the current private key matches the downloaded
  certificate, then the certificate will be saved and used for subsequent requests. If
  there is already an existing certificate, it will be overwritten.
HELP
  end

  option('--certname NAME') do |arg|
    options[:certname] = arg
  end

  def main
    if command_line.args.empty?
      puts help
      exit(1)
    end

    Puppet.settings.use(:main, :agent)
    Puppet::SSL::Host.ca_location = :remote
    host = Puppet::SSL::Host.new(options[:certname])

    action = command_line.args.first
    case action
    when 'submit_request'
      submit_request(host)
      download_cert(host)
    when 'download_cert'
      download_cert(host)
    else
      puts "Unknown action '#{action}'"
      exit(1)
    end

    exit(0)
  end

  def submit_request(host)
    host.ensure_ca_certificate

    host.submit_request
    puts "Submitted certificate request for '#{host.name}' to https://#{Puppet[:ca_server]}:#{Puppet[:ca_port]}"
  rescue => e
    puts "Failed to submit certificate request: #{e.message}"
    exit(1)
  end

  def download_cert(host)
    host.ensure_ca_certificate

    puts "Downloading certificate '#{host.name}' from https://#{Puppet[:ca_server]}:#{Puppet[:ca_port]}"
    if cert = host.download_host_certificate
      puts "Downloaded certificate '#{host.name}' with fingerprint #{cert.fingerprint}"
    else
      puts "No certificate for '#{host.name}' on CA"
    end
  rescue => e
    puts "Failed to download certificate: #{e.message}"
    exit(1)
  end
end
