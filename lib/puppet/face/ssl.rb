require 'puppet/face'
require 'puppet/ssl'

module PuppetX
  module Puppetlabs
    module Ssl
      def verify_signed_cert!(hostcert)
        if !hostcert.nil?
          Puppet.notice "Found a certificate for #{Puppet[:certname]}"
        else
          Puppet.err "No signed certificate found for #{Puppet[:certname]}"
          exit(1)
        end
      end

      def verify_ssl_files_match!(hostcert, hostkey)
        if hostcert.content.check_private_key(hostkey.content)
          Puppet.notice "Private key matches certificate"
        else
          Puppet.err "Signed certificate does not match host private key"
          exit(1)
        end
      end

      def verify_node_definition_reachable!
        Puppet::Node.indirection.find(Puppet[:node_name_value],
                                      environment: Puppet::Node::Environment.remote('production'),
                                      ignore_cache: true,
                                      fail_on_404: true)
        Puppet.notice("Contacted Puppet master for node definition")
      rescue => e
        Puppet.err "Unable to reach Puppet master: #{e.message}"
        exit(1)
      end
    end
  end
end

Puppet::Face.define(:ssl, '0.1.0') do
  copyright "Puppet Inc.", 2017
  license   _("Apache 2 license; see COPYING")
  summary "Initialize the Puppet agent"

  action(:generate_csr) do
    summary "Initialize the agent key pair and save a CSR"

    when_invoked do |opts|
      Puppet::SSL::Oids.register_puppet_oids
      Puppet::SSL::Oids.load_custom_oid_file(Puppet[:trusted_oid_mapping_file])

      Puppet::SSL::Host.localhost
    end
  end

  action(:purge) do
    summary "Purge all agent SSL files"
    when_invoked do |opts|
      Puppet.notice("Purging CA CRL")
      Puppet::SSL::CertificateRevocationList.indirection.destroy('ca')

      Puppet.notice("Purging agent certificate")
      Puppet::SSL::Certificate.indirection.destroy(Puppet[:certname])
      Puppet.notice("Purging agent certificate request")
      Puppet::SSL::CertificateRequest.indirection.destroy(Puppet[:certname])
      Puppet.notice("Purging agent key pair")
      Puppet::SSL::Key.indirection.destroy(Puppet[:certname])

      nil
    end
  end

  action(:verify) do
    summary "Verify that the Puppet agent has a signed certificate"

    when_invoked do |opts|
      extend PuppetX::Puppetlabs::Ssl
      hostcert = Puppet::SSL::Certificate.indirection.find(Puppet[:certname])
      hostkey = Puppet::SSL::Key.indirection.find(Puppet[:certname])

      verify_signed_cert!(hostcert)
      verify_ssl_files_match!(hostcert, hostkey)
      verify_node_definition_reachable!

      hostcert
    end

    when_rendering :console do |cert|
      cert.content.to_s if cert
    end
  end
end
