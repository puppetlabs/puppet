require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  class ArithmeticOperator < AST::Branch

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
      lval = Puppet::Parser::Scope.number?(lval)
      if lval == nil
        raise ArgumentError, "left operand of #{@operator} is not a number"
      end
      rval = @rval.safeevaluate(scope)
      rval = Puppet::Parser::Scope.number?(rval)
      if rval == nil
        raise ArgumentError, "right operand of #{@operator} is not a number"
      end

      # compute result
      lval.send(@operator, rval)
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid arithmetic operator #{@operator}" unless %w{+ - * / << >>}.include?(@operator)
    end
  end
end
