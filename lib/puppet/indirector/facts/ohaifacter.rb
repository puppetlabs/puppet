require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Ohaifacter < Puppet::Indirector::Code
  desc "Retrieve facts from Ohai and Facter.
    Merges facts from both facts terminii preferring Ohai facts if there is a conflict."

  # Look up a host's facts
  def find(request)
    facter = Puppet::Node::Facts.indirection.terminus(:facter).find(request)
    ohai = Puppet::Node::Facts.indirection.terminus(:ohai).find(request)
    Puppet::Node::Facts.new(request.key, facter.values.merge(ohai.values))
  end
end
