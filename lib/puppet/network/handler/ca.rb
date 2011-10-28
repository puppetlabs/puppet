require 'openssl'
require 'puppet'
require 'xmlrpc/server'
require 'puppet/network/handler'

class Puppet::Network::Handler
  class CA < Handler
    attr_reader :ca

    desc "Provides an interface for signing CSRs.  Accepts a CSR and returns
    the CA certificate and the signed certificate, or returns nil if
    the cert is not signed."

    @interface = XMLRPC::Service::Interface.new("puppetca") { |iface|
      iface.add_method("array getcert(csr)")
    }

    def initialize(hash = {})
      Puppet.settings.use(:main, :ssl, :ca)

      @ca = Puppet::SSL::CertificateAuthority.instance
    end

    # our client sends us a csr, and we either store it for later signing,
    # or we sign it right away
    def getcert(csrtext, client = nil, clientip = nil)
      csr = Puppet::SSL::CertificateRequest.from_s(csrtext)
      hostname = csr.name

      unless @ca
        Puppet.notice "Host #{hostname} asked for signing from non-CA master"
        return ""
      end

      # We used to save the public key, but it's basically unnecessary
      # and it mucks with the permissions requirements.

      # first check to see if we already have a signed cert for the host
      cert = Puppet::SSL::Certificate.indirection.find(hostname)
      cacert = Puppet::SSL::Certificate.indirection.find(@ca.host.name)

      if cert
        Puppet.info "Retrieving existing certificate for #{hostname}"
        unless csr.content.public_key.to_s == cert.content.public_key.to_s
          raise Puppet::Error, "Certificate request does not match existing certificate; run 'puppetca --clean #{hostname}'."
        end
        [cert.to_s, cacert.to_s]
      else
        Puppet::SSL::CertificateRequest.indirection.save(csr)

        # We determine whether we signed the csr by checking if there's a certificate for it
        if cert = Puppet::SSL::Certificate.indirection.find(hostname)
          [cert.to_s, cacert.to_s]
        else
          nil
        end
      end
    end
  end
end

