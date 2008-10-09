require 'puppet'
require 'puppet/parser/ast/branch'

# An object that returns a boolean which is the boolean not
# of the given value.
class Puppet::Parser::AST
    class Not < AST::Branch
        attr_accessor :value

        def each
            yield @value
        end

        def evaluate(scope)
            val = @value.safeevaluate(scope)
            return ! Puppet::Parser::Scope.true?(val)
        end
    end
end
