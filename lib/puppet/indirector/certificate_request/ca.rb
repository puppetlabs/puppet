require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_request'

class Puppet::SSL::CertificateRequest::Ca < Puppet::Indirector::SslFile
    desc "Manage the CA collection of certificate requests on disk."

    store_in :csrdir

    def save(request)
        result = super
        Puppet.notice "%s has a waiting certificate request" % request.key
        result
    end
end
