require 'puppet/parser/ast/hostclass'

# The specific code associated with a host.  Nodes are annoyingly unlike
# other objects.  That's just the way it is, at least for now.
class Puppet::Parser::AST::Node < Puppet::Parser::AST::HostClass

    associates_doc

    @name = :node

    def initialize(options)
        @parentclass = nil
        super
    end

    def namespace
        ""
    end

    # in Regex mode, our classname can't be our Regex.
    # so we use the currently connected client as our
    # classname, mimicing exactly what would have happened
    # if there was a specific node definition for this node.
    def get_classname(scope)
        return scope.host if name.regex?
        classname
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
