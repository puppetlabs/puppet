
# A Closure represents logic bound to a particular scope.
# As long as the runtime (basically the scope implementation) has the behaviour of Puppet 3x it is not
# safe to use this closure when the scope given to it when initialized goes "out of scope".
#
# Note that the implementation is backwards compatible in that the call method accepts a scope, but this
# scope is not used.
#
# Note that this class is a CallableSignature, and the methods defined there should be used
# as the API for obtaining information in a callable implementation agnostic way.
#
class Puppet::Pops::Evaluator::Closure < Puppet::Pops::Evaluator::CallableSignature
  attr_reader :evaluator
  attr_reader :model
  attr_reader :enclosing_scope

  def initialize(evaluator, model, scope)
    @evaluator = evaluator
    @model = model
    @enclosing_scope = scope
  end

  # marker method checked with respond_to :puppet_lambda
  # @api private
  # @deprecated Use the type system to query if an object is of Callable type, then use its signatures method for info
  def puppet_lambda()
    true
  end

  # compatible with 3x AST::Lambda
  # @api public
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

  # @api public
  def parameter_names
    @model.parameters.collect {|p| p.name }
  end

  # @api public
  def type
    @callable || create_callable_type
  end

  # @api public
  def last_captures_rest?
    # TODO: No support for this yet
    false
  end

  # @api public
  def block_name
    # TODO: Lambda's does not support blocks yet. This is a placeholder
    'unsupported_block'
  end

  private

  def create_callable_type()
    t = Puppet::Pops::Types::PCallableType.new()
    tuple_t = Puppet::Pops::Types::PTupleType.new()
    # since closure lambdas are currently untyped, each parameter becomes Optional[Object]
    parameter_names.each do |name|
      # TODO: Change when Closure supports typed parameters
      tuple_t.addTypes(Puppet::Pops::Types::TypeFactory.optional_object())
    end

    # TODO: A Lambda can not currently declare varargs
    to = parameter_count
    from = to - optional_parameter_count
    if from != to
      size_t = Puppet::Pops::Types::PIntegerType.new()
      size_t.from = size
      size_t.to = size
      tuple_t.size_type = size_t
    end
    t.param_types = tuple_t
    # TODO: A Lambda can not currently declare that it accepts a lambda, except as an explicit parameter
    # being a Callable
    t
  end

  # Produces information about parameters compatible with a 4x Function (which can have multiple signatures)
  def signatures
    [ self ]
  end

end
