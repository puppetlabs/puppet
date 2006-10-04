require 'puppet/parser/ast/hostclass'

class Puppet::Parser::AST
    # The specific code associated with a host.  Nodes are annoyingly unlike
    # other objects.  That's just the way it is, at least for now.
    class Node < AST::HostClass
        @name = :node
        attr_accessor :name

        #def evaluate(scope, facts = {})
        def evaluate(hash)
            scope = hash[:scope]

            #pscope = if ! Puppet[:lexical] or hash[:asparent]
            #    @scope
            #else
            #    origscope
            #end

            Puppet.warning "%s => %s" % [scope.type, self.name]

            # We don't have to worry about the declarativeness of node parentage,
            # because the entry point is always a single node definition.
            if parent = self.parentclass
                scope = parent.safeevaluate :scope => scope
            end
            Puppet.notice "%s => %s" % [scope.type, self.name]

            scope = scope.newscope(
                :type => self.name,
                :keyword => @keyword,
                :source => self,
                :namespace => "" # nodes are always in ""
            )
            Puppet.info "%s => %s" % [scope.type, self.name]

            # Mark our node name as a class, too, but strip it of the domain
            # name.  Make the mark before we evaluate the code, so that it is
            # marked within the code itself.
            scope.setclass(self)

            # And then evaluate our code if we have any
            if self.code
                @code.safeevaluate(:scope => scope)
            end

            return scope
        end

        def initialize(hash)
            @parentclass = nil
            super

            # Do some validation on the node name
            if @name =~ /[^-\w.]/
                raise Puppet::ParseError, "Invalid node name %s" % @name
            end
        end

        def parentclass
            parentobj do |name|
                @interp.nodesearch(name)
            end

            @parentclass
        end
    end
end

# $Id$
