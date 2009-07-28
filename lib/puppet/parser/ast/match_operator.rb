require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    class MatchOperator < AST::Branch

        attr_accessor :lval, :rval, :operator

        # Iterate across all of our children.
        def each
            [@lval,@rval].each { |child| yield child }
        end

        # Returns a boolean which is the result of the boolean operation
        # of lval and rval operands
        def evaluate(scope)
            lval = @lval.safeevaluate(scope)

            return @operator == "=~" if rval.evaluate_match(lval, scope)
            return @operator == "!~"
        end

        def initialize(hash)
            super

            unless %w{!~ =~}.include?(@operator)
                raise ArgumentError, "Invalid regexp operator %s" % @operator
            end
        end
    end
end
