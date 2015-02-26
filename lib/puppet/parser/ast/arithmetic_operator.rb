require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  class ArithmeticOperator < AST::Branch

    attr_accessor :operator, :lval, :rval

    # Iterate across all of our children.
    def each
      [@lval,@rval,@operator].each { |child| yield child }
    end

    # Produces an object which is the result of the applying the operator to the of lval and rval operands.
    # * Supports +, -, *, /, %, and <<, >> on numeric strings.
    # * Supports + on arrays (concatenate), and hashes (merge)
    # * Supports << on arrays (append)
    #
    def evaluate(scope)
      # evaluate the operands, should return a boolean value
      left = @lval.safeevaluate(scope)
      right = @rval.safeevaluate(scope)

      if left.is_a?(Array) || right.is_a?(Array)
        eval_array(left, right)
      elsif left.is_a?(Hash) || right.is_a?(Hash)
        eval_hash(left, right)
      else
        eval_numeric(left, right)
      end
    end

    # Concatenates (+) two arrays, or appends (<<) any object to a newly created array.
    #
    def eval_array(left, right)
      assert_concatenation_supported()

      raise ArgumentError, "operator #{@operator} is not applicable when one of the operands is an Array." unless %w{+ <<}.include?(@operator)
      raise ArgumentError, "left operand of #{@operator} must be an Array" unless left.is_a?(Array)
      if @operator == '+'
        raise ArgumentError, "right operand of #{@operator} must be an Array when left is an Array." unless right.is_a?(Array)
        return left + right
      end
      # only append case remains, left asserted to be an array, and right may be any object
      # wrapping right in an array and adding it ensures a new copy (operator << mutates).
      #
      left + [right]
    end

    # Merges two hashes.
    #
    def eval_hash(left, right)
      assert_concatenation_supported()

      raise ArgumentError, "operator #{@operator} is not applicable when one of the operands is an Hash." unless @operator == '+'
      raise ArgumentError, "left operand of #{@operator} must be an Hash" unless left.is_a?(Hash)
      raise ArgumentError, "right operand of #{@operator} must be an Hash" unless right.is_a?(Hash)
      # merge produces a merged copy
      left.merge(right)
    end

    def eval_numeric(left, right)
      left = Puppet::Parser::Scope.number?(left)
      right = Puppet::Parser::Scope.number?(right)
      raise ArgumentError, "left operand of #{@operator} is not a number" unless left != nil
      raise ArgumentError, "right operand of #{@operator} is not a number" unless right != nil

      # compute result
      left.send(@operator, right)
    end

    def assert_concatenation_supported
      return if Puppet.future_parser?
      raise ParseError.new("Unsupported Operation: Array concatenation available with '--parser future' setting only.")
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid arithmetic operator #{@operator}" unless %w{+ - * / % << >>}.include?(@operator)
    end
  end

  # Used by future parser instead of ArithmeticOperator to enable concatenation
  class ArithmeticOperator2 < ArithmeticOperator
    # Overrides the arithmetic operator to allow concatenation
    def assert_concatenation_supported
    end
  end

end
