require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_request'

class Puppet::SSL::CertificateRequest::Ca < Puppet::Indirector::SslFile
  desc "Manage the CA collection of certificate requests on disk."

  store_in :csrdir

  def save(request)
    if host = Puppet::SSL::Host.indirection.find(request.key)
      if Puppet[:allow_duplicate_certs]
        Puppet.notice _("#{request.key} already has a #{host.state} certificate; new certificate will overwrite it")
      else
        raise _("#{request.key} already has a #{host.state} certificate; ignoring certificate request")
      end
    end

    result = super
    Puppet.notice _("#{request.key} has a waiting certificate request")
    result
  end
end
