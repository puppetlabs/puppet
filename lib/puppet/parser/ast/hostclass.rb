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

            if klass == self.parentclass
                return true
            else
                return self.parentclass.child_of?(klass)
            end
        end

        # Evaluate the code associated with this class.
        def evaluate(hash)
            scope = hash[:scope]
            args = hash[:arguments]

            # Verify that we haven't already been evaluated
            if scope.setclass?(self)
                Puppet.debug "%s class already evaluated" % @type
                return nil
            end

            if @parentclass
                if pklass = self.parentclass
                    pklass.safeevaluate :scope => scope
                else
                    parsefail "Could not find class %s" % @parentclass
                end
            end

            # Set the class before we do anything else, so that it's set
            # during the evaluation and can be inspected.
            scope.setclass(self)

            unless hash[:nosubscope]
                scope = subscope(scope)
            end

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
    end
end

# $Id$
