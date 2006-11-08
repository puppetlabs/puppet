require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # Define a variable.  Stores the value in the current scope.
    class VarDef < AST::Branch
        attr_accessor :name, :value

        @settor = true

        # Look up our name and value, and store them appropriately.  The
        # lexer strips off the syntax stuff like '$'.
        def evaluate(hash)
            scope = hash[:scope]
            name = @name.safeevaluate(:scope => scope)
            value = @value.safeevaluate(:scope => scope)

            parsewrap do
                scope.setvar(name,value)
            end
        end

        def each
            [@name,@value].each { |child| yield child }
        end

        def tree(indent = 0)
            return [
                @name.tree(indent + 1),
                ((@@indline * 4 * indent) + self.typewrap(self.pin)),
                @value.tree(indent + 1)
            ].join("\n")
        end

        def to_s
            return "%s => %s" % [@name,@value]
        end
    end

end

# $Id$
