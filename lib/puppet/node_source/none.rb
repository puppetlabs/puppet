Puppet::Network::Handler::Node.newnode_source(:none, :fact_merge => true) do
    desc "Always return an empty node object.  This is the node source you should
        use when you don't have some other, functional source you want to use,
        as the compiler will not work without this node information."

    # Just return an empty node.
    def nodesearch(name)
        newnode(name)
    end
end
