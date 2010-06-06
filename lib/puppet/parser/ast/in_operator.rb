require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    class InOperator < AST::Branch

        attr_accessor :lval, :rval

        # Returns a boolean which is the result of the 'in' operation
        # of lval and rval operands
        def evaluate(scope)

            # evaluate the operands, should return a boolean value
            lval = @lval.safeevaluate(scope)
            unless lval.is_a?(::String)
                raise ArgumentError, "'#{lval}' from left operand of 'in' expression is not a string"
            end

            rval = @rval.safeevaluate(scope)
            unless rval.respond_to?(:include?)
                raise ArgumentError, "'#{rval}' from right operand of 'in' expression is not of a supported type (string, array or hash)"
            end
            return rval.include?(lval)
        end
    end
end
