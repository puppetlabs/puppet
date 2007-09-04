require 'puppet/parser/ast/hostclass'

class Puppet::Parser::AST
    # The specific code associated with a host.  Nodes are annoyingly unlike
    # other objects.  That's just the way it is, at least for now.
    class Node < AST::HostClass
        @name = :node
        attr_accessor :name

        #def evaluate(scope, facts = {})
        def evaluate(options)
            scope = options[:scope]

            #pscope = if ! Puppet[:lexical] or options[:asparent]
            #    @scope
            #else
            #    origscope
            #end

            # We don't have to worry about the declarativeness of node parentage,
            # because the entry point is always a single node definition.
            if parent = self.parentobj
                scope = parent.safeevaluate :scope => scope
            end

            scope = scope.newscope(
                :type => self.name,
                :keyword => @keyword,
                :source => self,
                :namespace => "" # nodes are always in ""
            )

            # Mark our node name as a class, too, but strip it of the domain
            # name.  Make the mark before we evaluate the code, so that it is
            # marked within the code itself.
            scope.compile.class_set(self.classname, scope)

            # And then evaluate our code if we have any
            if self.code
                @code.safeevaluate(:scope => scope)
            end

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
end
