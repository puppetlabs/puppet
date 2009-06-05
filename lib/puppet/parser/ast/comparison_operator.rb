require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    class ComparisonOperator < AST::Branch

        attr_accessor :operator, :lval, :rval

        # Iterate across all of our children.
        def each
            [@lval,@rval,@operator].each { |child| yield child }
        end

        # Returns a boolean which is the result of the boolean operation
        # of lval and rval operands
        def evaluate(scope)
            # evaluate the operands, should return a boolean value
            lval = @lval.safeevaluate(scope)
            rval = @rval.safeevaluate(scope)

            # convert to number if operands are number
            lval = Puppet::Parser::Scope.number?(lval) || lval
            rval = Puppet::Parser::Scope.number?(rval) || rval

            # return result
            unless @operator == '!='
                lval.send(@operator,rval)
            else
                lval != rval
            end
        end

        def initialize(hash)
            super

            unless %w{== != < > <= >=}.include?(@operator)
                raise ArgumentError, "Invalid comparison operator %s" % @operator
            end
        end
    end
end
