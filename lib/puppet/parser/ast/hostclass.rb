require 'puppet/parser/ast/component'

class Puppet::Parser::AST
    # The code associated with a class.  This is different from components
    # in that each class is a singleton -- only one will exist for a given
    # node.
    class HostClass < AST::Component
        @name = :class

        # Are we a child of the passed class?  Do a recursive search up our
        # parentage tree to figure it out.
        def child_of?(klass)
            return false unless self.parentclass

            if klass == self.parentobj
                return true
            else
                return self.parentobj.child_of?(klass)
            end
        end

        # Evaluate the code associated with this class.
        def evaluate(hash)
            scope = hash[:scope]
            args = hash[:arguments]

            # Verify that we haven't already been evaluated
            if scope.class_scope(self)
                Puppet.debug "%s class already evaluated" % @type
                return nil
            end

            pnames = nil
            if pklass = self.parentobj
                pklass.safeevaluate :scope => scope

                scope = parent_scope(scope, pklass)
                pnames = scope.namespaces
            end

            unless hash[:nosubscope]
                scope = subscope(scope)
            end

            if pnames
                pnames.each do |ns|
                    scope.add_namespace(ns)
                end
            end

            # Set the class before we do anything else, so that it's set
            # during the evaluation and can be inspected.
            scope.setclass(self)

            # Now evaluate our code, yo.
            if self.code
                return self.code.evaluate(:scope => scope)
            else
                return nil
            end
        end

        def initialize(hash)
            @parentclass = nil
            super
        end

        def parent_scope(scope, klass)
            if s = scope.class_scope(klass)
                return s
            else
                raise Puppet::DevError, "Could not find scope for %s" % klass.fqname
            end
        end
    end
end

# $Id$
