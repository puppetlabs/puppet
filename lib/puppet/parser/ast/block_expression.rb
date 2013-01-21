require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # A block of statements/expressions
  class BlockExpression < AST::Branch

    associates_doc

    attr_accessor :expressions

    def each
      yield @expressions
    end

    # Evaluate each expression/statement and produce the last expression evaluation result
    # @return [Object] what the last expression evaluated to
    def evaluate(scope)
      @expressions.safeevaluate(scope)
    end
  end
end
