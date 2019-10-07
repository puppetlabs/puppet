module Puppet::Pops
module Evaluator
  class Jumper < Exception
    attr_reader :value
    attr_reader :file
    attr_reader :line
    def initialize(value, file, line)
      @value = value
      @file = file
      @line = line
    end
  end

  class Next < Jumper
    def initialize(value, file, line)
      super
    end
  end

  class Return < Jumper
    def initialize(value, file, line)
      super
    end
  end

  class PuppetStopIteration < StopIteration
    attr_reader :file
    attr_reader :line
    attr_reader :pos

    def initialize(file, line, pos = nil)
      @file = file
      @line = line
      @pos = pos
    end

    def message
      "break() from context where this is illegal"
    end
  end

# A Closure represents logic bound to a particular scope.
# As long as the runtime (basically the scope implementation) has the behavior of Puppet 3x it is not
# safe to return and later use this closure.
#
# The 3x scope is essentially a named scope with an additional internal local/ephemeral nested scope state.
# In 3x there is no way to directly refer to the nested scopes, instead, the named scope must be in a particular
# state. Specifically, closures that require a local/ephemeral scope to exist at a later point will fail.
# It is safe to call a closure (even with 3x scope) from the very same place it was defined, but not
# returning it and expecting the closure to reference the scope's state at the point it was created.
#
# Note that this class is a CallableSignature, and the methods defined there should be used
# as the API for obtaining information in a callable-implementation agnostic way.
#
class Closure < CallableSignature
  attr_reader :evaluator
  attr_reader :model
  attr_reader :enclosing_scope

  def initialize(evaluator, model)
    @evaluator = evaluator
    @model = model
  end

  # Evaluates a closure in its enclosing scope after having matched given arguments with parameters (from left to right)
  # @api public
  def call(*args)
    call_with_scope(enclosing_scope, args)
  end

  # This method makes a Closure compatible with a Dispatch. This is used when the closure is wrapped in a Function
  # and the function is called. (Saves an extra Dispatch that just delegates to a Closure and avoids having two
  # checks of the argument type/arity validity).
  # @api private
  def invoke(instance, calling_scope, args, &block)
    enclosing_scope.with_global_scope do |global_scope|
      call_with_scope(global_scope, args, &block)
    end
  end

  def call_by_name_with_scope(scope, args_hash, enforce_parameters)
    call_by_name_internal(scope, args_hash, enforce_parameters)
  end

  def call_by_name(args_hash, enforce_parameters)
    call_by_name_internal(enclosing_scope, args_hash, enforce_parameters)
  end

  # Call closure with argument assignment by name
  def call_by_name_internal(closure_scope, args_hash, enforce_parameters)
    if enforce_parameters
      # Push a temporary parameter scope used while resolving the parameter defaults
      closure_scope.with_parameter_scope(closure_name, parameter_names) do |param_scope|
        # Assign all non-nil values, even those that represent non-existent parameters.
        args_hash.each { |k, v| param_scope[k] = v unless v.nil? }
        parameters.each do |p|
          name = p.name
          arg = args_hash[name]
          if arg.nil?
            # Arg either wasn't given, or it was undef
            if p.value.nil?
              # No default. Assign nil if the args_hash included it
              param_scope[name] = nil if args_hash.include?(name)
            else
              param_scope[name] = param_scope.evaluate(name, p.value, closure_scope, @evaluator)
            end
          end
        end
        args_hash = param_scope.to_hash
      end
      Types::TypeMismatchDescriber.validate_parameters(closure_name, params_struct, args_hash)
      result = catch(:next) do
        @evaluator.evaluate_block_with_bindings(closure_scope, args_hash, @model.body)
      end
      Types::TypeAsserter.assert_instance_of(nil, return_type, result) do
        "value returned from #{closure_name}"
      end
    else
      @evaluator.evaluate_block_with_bindings(closure_scope, args_hash, @model.body)
    end
  end
  private :call_by_name_internal

  def parameters
    @model.parameters
  end

  # Returns the number of parameters (required and optional)
  # @return [Integer] the total number of accepted parameters
  def parameter_count
    # yes, this is duplication of code, but it saves a method call
    @model.parameters.size
  end

  # @api public
  def parameter_names
    @model.parameters.collect(&:name)
  end

  def return_type
    @return_type ||= create_return_type
  end

  # @api public
  def type
    @callable ||= create_callable_type
  end

  # @api public
  def params_struct
    @params_struct ||= create_params_struct
  end

  # @api public
  def last_captures_rest?
    last = @model.parameters[-1]
    last && last.captures_rest
  end

  # @api public
  def block_name
    # TODO: Lambda's does not support blocks yet. This is a placeholder
    'unsupported_block'
  end

  CLOSURE_NAME = 'lambda'.freeze

  # @api public
  def closure_name()
    CLOSURE_NAME
  end

  class Dynamic < Closure
    def initialize(evaluator, model, scope)
      @enclosing_scope = scope
      super(evaluator, model)
    end

    def enclosing_scope
      @enclosing_scope
    end

    def call(*args)
      # A return from an unnamed closure is treated as a return from the context evaluating
      # calling this closure - that is, as if it was the return call itself.
      #
      jumper = catch(:return) do
        return call_with_scope(enclosing_scope, args)
      end
      raise jumper
    end
  end

  class Named < Closure
    def initialize(name, evaluator, model)
      @name = name
      super(evaluator, model)
    end

    def closure_name
      @name
    end

    # The assigned enclosing scope, or global scope if enclosing scope was initialized to nil
    #
    def enclosing_scope
      # Named closures are typically used for puppet functions and they cannot be defined
      # in an enclosing scope as they are cashed and reused. They need to bind to the
      # global scope at time of use rather at time of definition.
      # Unnamed closures are always a runtime construct, they are never bound by a loader
      # and are thus garbage collected at end of a compilation.
      #
      Puppet.lookup(:global_scope) { {} }
    end
  end

  private

  def call_with_scope(scope, args)
    variable_bindings = combine_values_with_parameters(scope, args)

    tc = Types::TypeCalculator.singleton
    final_args = tc.infer_set(parameters.reduce([]) do |tmp_args, param|
      if param.captures_rest
        tmp_args.concat(variable_bindings[param.name])
      else
        tmp_args << variable_bindings[param.name]
      end
    end)

    if type.callable?(final_args)
      result = catch(:next) do
        @evaluator.evaluate_block_with_bindings(scope, variable_bindings, @model.body)
      end
      Types::TypeAsserter.assert_instance_of(nil, return_type, result) do
        "value returned from #{closure_name}"
      end
    else
      raise ArgumentError, Types::TypeMismatchDescriber.describe_signatures(closure_name, [self], final_args)
    end
  end

  def combine_values_with_parameters(scope, args)
    scope.with_parameter_scope(closure_name, parameter_names) do |param_scope|
      parameters.each_with_index do |parameter, index|
        param_captures     = parameter.captures_rest
        default_expression = parameter.value

        if index >= args.size
          if default_expression
            # not given, has default
            value = param_scope.evaluate(parameter.name, default_expression, scope, @evaluator)

            if param_captures && !value.is_a?(Array)
              # correct non array default value
              value = [value]
            end
          else
            # not given, does not have default
            if param_captures
              # default for captures rest is an empty array
              value = []
            else
              @evaluator.fail(Issues::MISSING_REQUIRED_PARAMETER, parameter, { :param_name => parameter.name })
            end
          end
        else
          given_argument = args[index]
          if param_captures
            # get excess arguments
            value = args[(parameter_count-1)..-1]
            # If the input was a single nil, or undef, and there is a default, use the default
            # This supports :undef in case it was used in a 3x data structure and it is passed as an arg
            #
            if value.size == 1 && (given_argument.nil? || given_argument == :undef) && default_expression
              value = param_scope.evaluate(parameter.name, default_expression, scope, @evaluator)
              # and ensure it is an array
              value = [value] unless value.is_a?(Array)
            end
          else
            value = given_argument
          end
        end
        param_scope[parameter.name] = value
      end
      param_scope.to_hash
    end
  end

  def create_callable_type()
    types = []
    from = 0
    to = 0
    in_optional_parameters = false
    closure_scope = enclosing_scope

    parameters.each do |param|
      type, param_range = create_param_type(param, closure_scope)

      types << type

      if param_range[0] == 0
        in_optional_parameters = true
      elsif param_range[0] != 0 && in_optional_parameters
        @evaluator.fail(Issues::REQUIRED_PARAMETER_AFTER_OPTIONAL, param, { :param_name => param.name })
      end

      from += param_range[0]
      to += param_range[1]
    end
    param_types = Types::PTupleType.new(types, Types::PIntegerType.new(from, to))
    Types::PCallableType.new(param_types, nil, return_type)
  end

  def create_params_struct
    type_factory = Types::TypeFactory
    members = {}
    closure_scope = enclosing_scope

    parameters.each do |param|
      arg_type, _ = create_param_type(param, closure_scope)
      key_type = type_factory.string(param.name.to_s)
      key_type = type_factory.optional(key_type) unless param.value.nil?
      members[key_type] = arg_type
    end
    type_factory.struct(members)
  end

  def create_return_type
    if @model.return_type
      @evaluator.evaluate(@model.return_type, @enclosing_scope)
    else
      Types::PAnyType::DEFAULT
    end
  end

  def create_param_type(param, closure_scope)
    type = if param.type_expr
             @evaluator.evaluate(param.type_expr, closure_scope)
           else
             Types::PAnyType::DEFAULT
           end

    if param.captures_rest && type.is_a?(Types::PArrayType)
      # An array on a slurp parameter is how a size range is defined for a
      # slurp (Array[Integer, 1, 3] *$param). However, the callable that is
      # created can't have the array in that position or else type checking
      # will require the parameters to be arrays, which isn't what is
      # intended. The array type contains the intended information and needs
      # to be unpacked.
      param_range = type.size_range
      type = type.element_type
    elsif param.captures_rest && !type.is_a?(Types::PArrayType)
      param_range = ANY_NUMBER_RANGE
    elsif param.value
      param_range = OPTIONAL_SINGLE_RANGE
    else
      param_range = REQUIRED_SINGLE_RANGE
    end
    [type, param_range]
  end

  # Produces information about parameters compatible with a 4x Function (which can have multiple signatures)
  def signatures
    [ self ]
  end

  ANY_NUMBER_RANGE = [0, Float::INFINITY]
  OPTIONAL_SINGLE_RANGE = [0, 1]
  REQUIRED_SINGLE_RANGE = [1, 1]
end
end
end
