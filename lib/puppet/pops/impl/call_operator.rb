# CallOperator
# Call operator is part of evaluation
# 
module Puppet; module Pops; module Impl

  class CallOperator
    attr_reader :eval_visitor
    def initialize
      @call_visitor = Visitor.new(self, "call", 2, 2)
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
end; end; end;