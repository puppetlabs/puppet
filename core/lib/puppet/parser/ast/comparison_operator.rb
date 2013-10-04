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

      case @operator
      when "==","!="
        @rval.evaluate_match(lval, scope) ? @operator == '==' : @operator == '!='
      else
        rval = @rval.safeevaluate(scope)
        rval = Puppet::Parser::Scope.number?(rval) || rval
        lval = Puppet::Parser::Scope.number?(lval) || lval

        lval.send(@operator,rval)
      end
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid comparison operator #{@operator}" unless %w{== != < > <= >=}.include?(@operator)
    end
  end
end
