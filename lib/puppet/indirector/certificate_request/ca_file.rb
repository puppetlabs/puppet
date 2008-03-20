require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_request'

class Puppet::SSL::CertificateRequest::CaFile < Puppet::Indirector::SslFile
    desc "Manage the CA collection of certificate requests on disk."

    store_in :csrdir

    def save(instance, *args)
        result = super
        Puppet.notice "%s has a waiting certificate request" % instance.name
        result
    end
end
