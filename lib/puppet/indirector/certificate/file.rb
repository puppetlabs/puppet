require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate'

# @deprecated
class Puppet::SSL::Certificate::File < Puppet::Indirector::SslFile
  desc "Manage SSL certificates on disk."

  store_in :certdir
end
