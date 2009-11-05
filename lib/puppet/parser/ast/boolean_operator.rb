require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    class BooleanOperator < AST::Branch

        attr_accessor :operator, :lval, :rval

        # Iterate across all of our children.
        def each
            [@lval,@rval,@operator].each { |child| yield child }
        end

        # Returns a boolean which is the result of the boolean operation
        # of lval and rval operands
        def evaluate(scope)
            # evaluate the first operand, should return a boolean value
            lval = @lval.safeevaluate(scope)

            # return result
            # lazy evaluate right operand
            case @operator
            when "and"
                if Puppet::Parser::Scope.true?(lval)
                    rval = @rval.safeevaluate(scope)
                    Puppet::Parser::Scope.true?(rval)
                else # false and false == false
                    false
                end
            when "or"
                if Puppet::Parser::Scope.true?(lval)
                    true
                else
                    rval = @rval.safeevaluate(scope)
                    Puppet::Parser::Scope.true?(rval)
                end
            end
        end

        def initialize(hash)
            super

            unless %w{and or}.include?(@operator)
                raise ArgumentError, "Invalid boolean operator %s" % @operator
            end
        end
    end
end
