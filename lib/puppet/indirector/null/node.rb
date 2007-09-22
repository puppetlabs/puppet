require 'puppet/indirector/null'

class Puppet::Indirector::Null::Node < Puppet::Indirector::Null
    desc "Always return an empty node object.  This is the node source you should
        use when you don't have some other, functional source you want to use,
        as the compiler will not work without this node information."

    # Just return an empty node.
    def find(name)
        node = super
        node.fact_merge
        node
    end
end
