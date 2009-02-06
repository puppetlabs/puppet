require 'puppet/agent'
require 'puppet/agent/runner'
require 'puppet/indirector/rest'

class Puppet::Agent::Runner::Rest < Puppet::Indirector::REST
    desc "Trigger Agent runs via REST."
end
