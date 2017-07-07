require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_request'

class Puppet::SSL::CertificateRequest::Ca < Puppet::Indirector::SslFile
  desc "Manage the CA collection of certificate requests on disk."

  store_in :csrdir

  def save(request)
    if host = Puppet::SSL::Host.indirection.find(request.key)
      if Puppet[:allow_duplicate_certs]
        Puppet.notice _("%{request} already has a %{host} certificate; new certificate will overwrite it") % { request: request.key, host: host.state }
      else
        raise _("%{request} already has a %{host} certificate; ignoring certificate request") % { request: request.key, host: host.state }
      end
    end

    result = super
    Puppet.notice _("%{request} has a waiting certificate request") % { request: request.key }
    result
  end
end
