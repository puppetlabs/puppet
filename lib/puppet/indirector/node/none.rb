require 'puppet/node/facts'

Puppet::Indirector.register_terminus :node, :none do
    desc "Always return an empty node object.  This is the node source you should
        use when you don't have some other, functional source you want to use,
        as the compiler will not work without this node information."

    # Just return an empty node.
    def find(name)
        node = Puppet::Node.new(name)
        node.fact_merge
        node
    end
end
