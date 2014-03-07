
# A Closure represents logic bound to a particular scope.
# As long as the runtime (basically the scope implementation) has the behaviour of Puppet 3x it is not
# safe to use this closure when the scope given to it when initialized goes "out of scope".
# 
# Note that the implementation is backwards compatible in that the call method accepts a scope, but this
# scope is not used.
#
class Puppet::Pops::Evaluator::Closure
  attr_reader :evaluator
  attr_reader :model
  attr_reader :enclosing_scope

  def initialize(evaluator, model, scope)
    @evaluator = evaluator
    @model = model
    @enclosing_scope = scope
  end

  # marker method checked with respond_to :puppet_lambda
  def puppet_lambda()
    true
  end

  # compatible with 3x AST::Lambda
  def call(scope, *args)
    @evaluator.call(self, args, @enclosing_scope)
  end

  # Call closure with argument assignment by name
  def call_by_name(scope, args_hash, spill_over = false)
    @evaluator.call_by_name(self, args_hash, @enclosing_scope, spill_over)
  end

  # incompatible with 3x except that it is an array of the same size
  def parameters()
    @model.parameters || []
  end

  # Returns the number of parameters (required and optional)
  # @return [Integer] the total number of accepted parameters
  def parameter_count
    # yes, this is duplication of code, but it saves a method call
    (@model.parameters || []).size
  end

  # Returns the number of optional parameters.
  # @return [Integer] the number of optional accepted parameters
  def optional_parameter_count
    @model.parameters.count { |p| !p.value.nil? }
  end

  def parameter_names
    @model.parameters.collect {|p| p.name }
  end

end
