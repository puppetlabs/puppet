require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Facter < Puppet::Indirector::Code
    desc "Retrieve facts from Facter.  This provides a somewhat abstract interface
        between Puppet and Facter.  It's only `somewhat` abstract because it always
        returns the local host's facts, regardless of what you attempt to find."

    def destroy(facts)
        raise Puppet::DevError, "You cannot destroy facts in the code store; it is only used for getting facts from Facter"
    end

    # Look a host's facts up in Facter.
    def find(key)
        Puppet::Node::Facts.new(key, Facter.to_hash)
    end

    def save(facts)
        raise Puppet::DevError, "You cannot save facts to the code store; it is only used for getting facts from Facter"
    end
end
