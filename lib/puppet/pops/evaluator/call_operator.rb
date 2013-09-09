# CallOperator
# Call operator is part of evaluation
#
class Puppet::Pops::Evaluator::CallOperator
  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  attr_reader :eval_visitor
  def initialize
    @call_visitor = Puppet::Pops::Visitor.new(self, "call", 2, 2)
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
