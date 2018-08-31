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

    action = command_line.args.first
    case action
    when 'submit_request'
      submit_request(options[:certname])
    else
      puts "Unknown action '#{action}'"
      exit(1)
    end
  end

  def submit_request(certname = nil)
    Puppet::SSL::Host.ca_location = :remote
    ssl = Puppet::SSL::Host.new(certname)
    ssl.ensure_ca_certificate
    ssl.generate_certificate_request(dns_alt_names: '')
    puts "Submitted certificate request for '#{ssl.name}' to https://#{Puppet[:ca_server]}:#{Puppet[:ca_port]}"
  rescue => e
    puts "Failed to submit certificate request: #{e.message}"
    exit 1
  end
end
