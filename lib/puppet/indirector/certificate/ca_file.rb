require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate'

class Puppet::SSL::Certificate::CaFile < Puppet::Indirector::SslFile
    desc "Manage the CA collection of signed SSL certificates on disk."

    store_in :signeddir
end
