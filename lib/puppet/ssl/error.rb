module Puppet::SSL
  class SSLError < Puppet::Error; end

  class CertVerifyError < Puppet::SSL::SSLError
    attr_reader :code, :cert
    def initialize(message, code, cert)
      super(message)
      @code = code
      @cert = cert
    end
  end

  class CertMismatchError < Puppet::SSL::SSLError
    def initialize(peer_cert, host)
      valid_certnames = [peer_cert.subject.to_utf8.sub(/.*=/, ''),
                         *Puppet::SSL::Certificate.subject_alt_names_for(peer_cert)].uniq
      if valid_certnames.size > 1
        expected_certnames = _("expected one of %{certnames}") % { certnames: valid_certnames.join(', ') }
      else
        expected_certnames = _("expected %{certname}") % { certname: valid_certnames.first }
      end

      super(_("Server hostname '%{host}' did not match server certificate; %{expected_certnames}") % { host: host, expected_certnames: expected_certnames })
    end
  end
end
