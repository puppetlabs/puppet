require 'puppet/ssl/certificate'
require 'puppet/indirector/rest'

class Puppet::SSL::Certificate::Rest < Puppet::Indirector::REST
    desc "Find and save certificates over HTTP via REST."
end
