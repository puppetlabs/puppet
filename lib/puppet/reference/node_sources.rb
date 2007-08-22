noderef = Puppet::Util::Reference.newreference :node_source, :doc => "Sources of node configuration information" do
    Puppet::Network::Handler.node.sourcedocs
end

nodref.header = "
Nodes can be searched for in different locations.  This document describes those different locations.
"
