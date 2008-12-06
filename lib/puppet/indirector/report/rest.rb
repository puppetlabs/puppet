require 'puppet/indirector/rest'

class Puppet::Transaction::Report::Rest < Puppet::Indirector::REST
    desc "Get server report over HTTP via REST."
end
