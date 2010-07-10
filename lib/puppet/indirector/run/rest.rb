require 'puppet/run'
require 'puppet/indirector/rest'

class Puppet::Run::Rest < Puppet::Indirector::REST
  desc "Trigger Agent runs via REST."
end
