require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Facterohai < Puppet::Indirector::Code
  desc "Retrieve facts from Ohai and Facter.
    Merges facts from both facts terminii preferring Facter facts if there is a conflict."

  # Look up a host's facts
  def find(request)
    facter = Puppet::Node::Facts.indirection.terminus(:facter).find(request)
    ohai = Puppet::Node::Facts.indirection.terminus(:ohai).find(request)
    Puppet::Node::Facts.new(request.key, ohai.values.merge(facter.values))
  end
end
