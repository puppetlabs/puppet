require 'puppet/node'
require 'puppet/indirector/rest'

class Puppet::Node::REST < Puppet::Indirector::REST
    desc "This will eventually be a REST-based mechanism for finding nodes.  It is currently non-functional."
    # TODO/FIXME
end
