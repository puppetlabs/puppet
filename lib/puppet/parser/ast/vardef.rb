require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # Define a variable.  Stores the value in the current scope.
    class VarDef < AST::Branch

        associates_doc

        attr_accessor :name, :value, :append

        @settor = true

        # Look up our name and value, and store them appropriately.  The
        # lexer strips off the syntax stuff like '$'.
        def evaluate(scope)
            name = @name.safeevaluate(scope)
            value = @value.safeevaluate(scope)

            parsewrap do
                scope.setvar(name,value, :file => @file, :line => @line, :append => @append)
            end
        end

        def each
            [@name,@value].each { |child| yield child }
        end
    end

end
