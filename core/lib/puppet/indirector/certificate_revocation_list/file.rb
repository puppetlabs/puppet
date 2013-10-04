require 'puppet/indirector/ssl_file'
require 'puppet/ssl/certificate_revocation_list'

class Puppet::SSL::CertificateRevocationList::File < Puppet::Indirector::SslFile
  desc "Manage the global certificate revocation list."

  store_at :hostcrl
end
