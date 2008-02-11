require 'puppet/parser/ast/hostclass'

# The specific code associated with a host.  Nodes are annoyingly unlike
# other objects.  That's just the way it is, at least for now.
class Puppet::Parser::AST::Node < Puppet::Parser::AST::HostClass
    @name = :node

    # Evaluate the code associated with our node definition.
    def evaluate_code(resource)
        scope = resource.scope

        # We don't have to worry about the declarativeness of node parentage,
        # because the entry point is always a single node definition.
        if parent = self.parentobj
            scope = parent.evaluate_code(resource)
        end

        scope = scope.newscope(
            :resource => resource,
            :keyword => @keyword,
            :source => self,
            :namespace => "" # nodes are always in ""
        )

        # Mark our node name as a class, too, but strip it of the domain
        # name.  Make the mark before we evaluate the code, so that it is
        # marked within the code itself.
        scope.compiler.class_set(self.classname, scope)

        # And then evaluate our code if we have any
        @code.safeevaluate(scope) if self.code

        return scope
    end

    def initialize(options)
        @parentclass = nil
        super

        # Do some validation on the node name
        if @name =~ /[^-\w.]/
            raise Puppet::ParseError, "Invalid node name %s" % @name
        end
    end

    # Make sure node scopes are marked as such.
    def subscope(*args)
        scope = super
        scope.nodescope = true
    end

    private
    # Search for the object matching our parent class.
    def find_parentclass
        @parser.findnode(parentclass)
    end
end
