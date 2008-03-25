require 'puppet/node'
require 'puppet/indirector/plain'

class Puppet::Node::Plain < Puppet::Indirector::Plain
    desc "Always return an empty node object. Assumes you keep track of nodes
        in flat file manifests.  You should use it when you don't have some other,
        functional source you want to use, as the compiler will not work without a
        valid node terminus.

        Note that class is responsible for merging the node's facts into the
        node instance before it is returned."

    # Just return an empty node.
    def find(name)
        node = super
        node.fact_merge
        node
    end

    # Use the version of the facts, since we assume that's the main thing
    # that changes.  If someone wants their own way of defining version,
    # they can easily provide their own, um, version of this class.
    def version(name)
        Puppet::Node::Facts.version(name)
    end
end
