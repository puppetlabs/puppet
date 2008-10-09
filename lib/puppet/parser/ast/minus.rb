require 'puppet'
require 'puppet/parser/ast/branch'

# An object that returns a boolean which is the boolean not
# of the given value.
class Puppet::Parser::AST
    class Minus < AST::Branch
        attr_accessor :value

        def each
            yield @value
        end

        def evaluate(scope)
            val = @value.safeevaluate(scope)
            val = Puppet::Parser::Scope.number?(val)
            if val == nil
                raise ArgumentError, "minus operand %s is not a number" % val
            end
            return -val
        end
    end
end
