require 'puppet/indirector/face'
require 'puppet/ssl/host'
require 'puppet/ssl/certificate_authority'
require 'puppet/ssl/ocsp'
require 'puppet/ssl/ocsp/response'
require 'puppet/ssl/ocsp/request'

Puppet::Indirector::Face.define(:ocsp, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Verify certificate revocation status through OCSP"
  description <<-EOT
    This subcommand allows to check a certificate revocation status against a
    a remote Puppet CA server.
  EOT

  action :verify do
    summary "Verify through OCSP that the given certificate has been revoked or not."
    arguments "<certificate>"
    returns "When used from the Ruby API an array of instance of a Puppet::SSL::Ocsp request and Puppet::SSL::OcspResponse"
    description <<-EOT
      Ask a remote OCSP responder (usually a remote Puppet CA) about the certificate
      revocation status of a given certificate.
    EOT
    examples <<-EOT
      puppet ocsp verify node01.puppetlabs.com
    EOT

    when_invoked do |certificate,options|
      raise "Impossible to load certificate for #{certificate}" unless to_check = Puppet::SSL::Certificate.indirection.find(certificate)
      raise "Impossible to load CA certificate" unless ca = Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME)
      unless cert = Puppet::SSL::Host.localhost.certificate
        Puppet.warning "Can't find local node certificate, OCSP request will not be signed"
      end
      unless key = Puppet::SSL::Host.localhost.key
        Puppet.warning "Can't find local node private key, OCSP request will not be signed"
      end

      Puppet::SSL::Host.ca_location = :remote

      begin
        status = Puppet::SSL::Ocsp::Verifier.verify(to_check, Puppet::SSL::Host.localhost)
        if status[0][:valid]
          { :host => certificate, :valid => true, :response => status }
        else
          { :host => certificate, :valid => false, :reason => Puppet::SSL::Ocsp.code_to_reason(status[0][:revocation_reason]) }
        end
      rescue Puppet::SSL::Ocsp::Response::VerificationError => e
        { :host => certificate, :valid => false, :error => e.to_s }
      end
    end

    when_rendering :console do |value|
      if value[:valid]
        "Certificate is valid"
      elsif value.include?(:reason)
        "Invalid certificate: #{value[:reason]}"
      else
        "Could not verify #{value[:host]}: #{value[:error]}"
      end
    end
  end

  get_action(:save).summary "Invalid for this subcommand."
  get_action(:find).summary "Invalid for this subcommand."
  get_action(:destroy).summary "Invalid for this subcommand."
  get_action(:search).summary "Invalid for this subcommand."
end
