Puppet::Indirector.register_terminus :node, :none do
    desc "Always return an empty node object.  This is the node source you should
        use when you don't have some other, functional source you want to use,
        as the compiler will not work without this node information."

    # Just return an empty node.
    def get(name)
        node = Puppet::Node.new(name)
        if facts = Puppet::Node.facts(name)
            node.fact_merge(facts)
        end
        node
    end
end
