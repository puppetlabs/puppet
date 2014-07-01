
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
    variable_bindings = combine_values_with_parameters(args)

    tc = Puppet::Pops::Types::TypeCalculator
    final_args = tc.infer_set(parameters.inject([]) do |final_args, param|
      if param.captures_rest
        final_args.concat(variable_bindings[param.name])
      else
        final_args << variable_bindings[param.name]
      end
    end)

    if tc.callable?(type, final_args)
      @evaluator.evaluate_block_with_bindings(@enclosing_scope, variable_bindings, @model.body)
    else
      raise ArgumentError, "lambda called with mis-matched arguments\n#{Puppet::Pops::Evaluator::CallableMismatchDescriber.diff_string('lambda', final_args, [self])}"
    end
  end

  # Call closure with argument assignment by name
  def call_by_name(scope, args_hash, enforce_parameters)
    if enforce_parameters
      if args_hash.size > parameters.size
        raise ArgumentError, "Too many arguments: #{args_hash.size} for #{parameters.size}"
      end

      # associate values with parameters
      scope_hash = {}
      parameters.each do |p|
        name = p.name
        if (arg_value = args_hash[name]).nil?
          # only set result of default expr if it is defined (it is otherwise not possible to differentiate
          # between explicit undef and no default expression
          unless p.value.nil?
            scope_hash[name] = @evaluator.evaluate(p.value, @enclosing_scope)
          end
        else
          scope_hash[name] = arg_value
        end
      end

      missing = parameters.select { |p| !scope_hash.include?(p.name) }
      if missing.any?
        raise ArgumentError, "Too few arguments; no value given for required parameters #{missing.collect(&:name).join(" ,")}"
      end

      tc = Puppet::Pops::Types::TypeCalculator
      final_args = tc.infer_set(parameter_names.collect { |param| scope_hash[param] })
      if !tc.callable?(type, final_args)
        raise ArgumentError, "lambda called with mis-matched arguments\n#{Puppet::Pops::Evaluator::CallableMismatchDescriber.diff_string('lambda', final_args, [self])}"
      end
    else
      scope_hash = args_hash
    end

    @evaluator.evaluate_block_with_bindings(@enclosing_scope, scope_hash, @model.body)
  end

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

  # @api public
  def type
    @callable ||= create_callable_type
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

  private

  def combine_values_with_parameters(args)
    variable_bindings = {}

    parameters.each_with_index do |parameter, index|
      param_captures     = parameter.captures_rest
      default_expression = parameter.value

      if index >= args.size
        if default_expression
          # not given, has default
          value = @evaluator.evaluate(default_expression, @enclosing_scope)
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
            @evaluator.fail(Puppet::Pops::Issues::MISSING_REQUIRED_PARAMETER, parameter, { :param_name => parameter.name })
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
            value = @evaluator.evaluate(default_expression, scope)
            # and ensure it is an array
            value = [value] unless value.is_a?(Array)
          end
        else
          value = given_argument
        end
      end

      variable_bindings[parameter.name] = value
    end

    variable_bindings
  end

  def create_callable_type()
    types = []
    range = [0, 0]
    in_optional_parameters = false
    parameters.each do |param|
      type = if param.type_expr
               @evaluator.evaluate(param.type_expr, @enclosing_scope)
             else
               Puppet::Pops::Types::TypeFactory.any()
             end

      if param.captures_rest && type.is_a?(Puppet::Pops::Types::PArrayType)
        # An array on a slurp parameter is how a size range is defined for a
        # slurp (Array[Integer, 1, 3] *$param). However, the callable that is
        # created can't have the array in that position or else type checking
        # will require the parameters to be arrays, which isn't what is
        # intended. The array type contains the intended information and needs
        # to be unpacked.
        param_range = type.size_range
        type = type.element_type
      elsif param.captures_rest && !type.is_a?(Puppet::Pops::Types::PArrayType)
        param_range = ANY_NUMBER_RANGE
      elsif param.value
        param_range = OPTIONAL_SINGLE_RANGE
      else
        param_range = REQUIRED_SINGLE_RANGE
      end

      types << type

      if param_range[0] == 0
        in_optional_parameters = true
      elsif param_range[0] != 0 && in_optional_parameters
        @evaluator.fail(Puppet::Pops::Issues::REQUIRED_PARAMETER_AFTER_OPTIONAL, param, { :param_name => param.name })
      end

      range[0] += param_range[0]
      range[1] += param_range[1]
    end

    if range[1] == Puppet::Pops::Types::INFINITY
      range[1] = :default
    end

    Puppet::Pops::Types::TypeFactory.callable(*(types + range))
  end

  # Produces information about parameters compatible with a 4x Function (which can have multiple signatures)
  def signatures
    [ self ]
  end

  ANY_NUMBER_RANGE = [0, Puppet::Pops::Types::INFINITY]
  OPTIONAL_SINGLE_RANGE = [0, 1]
  REQUIRED_SINGLE_RANGE = [1, 1]
end
