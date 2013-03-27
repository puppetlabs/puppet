# CallOperator
# Call operator is part of evaluation
#
module Puppet; module Pops; end; end

module Puppet::Pops::Impl
  class CallOperator
    attr_reader :eval_visitor
    def initialize
      @call_visitor = Puppet::Pops::API::Visitor.new(self, "call", 2, 2)
    end

    def call (o, scope, *params, &block)
      x = @call_visitor.visit(o, scope, params)
      if block_given?
        block.call(x)
      else
        x
      end
    end

    protected

    def call_FunctionExpression o, scope, params
    end
  end
end