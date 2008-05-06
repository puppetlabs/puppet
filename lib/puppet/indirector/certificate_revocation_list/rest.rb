require 'puppet/ssl/certificate_revocation_list'
require 'puppet/indirector/rest'

class Puppet::SSL::CertificateRevocationList::Rest < Puppet::Indirector::REST
    desc "Find and save certificate revocation lists over HTTP via REST."
end
