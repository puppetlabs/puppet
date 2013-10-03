require 'puppet/node/facts'
require 'puppet/indirector/code'
require 'ohai'

class Puppet::Node::Facts::Ohai < Puppet::Indirector::Code
  desc "Retrieve facts from Ohai.  This provides a somewhat abstract interface
    between Puppet and Ohai.  It's only `somewhat` abstract because it always
    returns the local host's facts, regardless of what you attempt to find."

  # Look a host's facts up in Ohai.
  def find(request)
    ohai = Ohai::System.new
    ohai.all_plugins
    result = Puppet::Node::Facts.new(request.key, ohai.data)

    result.add_local_facts

    result
  end
end
