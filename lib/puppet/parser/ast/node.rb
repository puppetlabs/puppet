require 'puppet/parser/ast/hostclass'

# The specific code associated with a host.  Nodes are annoyingly unlike
# other objects.  That's just the way it is, at least for now.
class Puppet::Parser::AST::Node < Puppet::Parser::AST::HostClass

    associates_doc

    @name = :node

    def initialize(options)
        @parentclass = nil
        super

        # Do some validation on the node name
        if @name =~ /[^-\w.]/
            raise Puppet::ParseError, "Invalid node name %s" % @name
        end
    end

    def namespace
        ""
    end

    # Make sure node scopes are marked as such.
    def subscope(*args)
        scope = super
        scope.nodescope = true
        scope
    end

    private

    # Search for the object matching our parent class.
    def find_parentclass
        @parser.node(parentclass)
    end
end
