require 'puppet/node'
require 'puppet/indirector/null'

class Puppet::Node::Null < Puppet::Indirector::Null
    desc "Always return an empty node object.  This is the node source you should
        use when you don't have some other, functional source you want to use,
        as the compiler will not work without a valid node terminus.
        
        Note that class is responsible for merging the node's facts into the node
        instance before it is returned."

    # Just return an empty node.
    def find(name)
        node = super
        node.fact_merge
        node
    end
end
