require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_request'

class Puppet::SSL::CertificateRequest::File < Puppet::Indirector::SslFile
    desc "Manage the collection of certificate requests on disk."

    store_in :requestdir
end
