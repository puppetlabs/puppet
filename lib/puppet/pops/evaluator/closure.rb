
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
    tc = Puppet::Pops::Types::TypeCalculator
    actual = tc.infer_set(args)
    if tc.callable?(type, actual)
      parameters_size = parameters.size
      last_captures_rest = parameters_size > 0 && parameters[-1].captures_rest
      args_size = args.size

      unless args_size <= parameters_size || last_captures_rest
        raise ArgumentError, "Too many arguments: #{args_size} for #{parameters_size}"
      end

      args_diff = parameters.size - args.size
      # associate values with parameters (NOTE: excess args for captures rest are not included in merged)
      merged = parameters.zip(args.fill(:missing, args.size, args_diff)) #args)

      # calculate missing arguments
      if args_diff > 0
        missing = parameters.slice(args_size, args_diff).select {|p| p.value.nil? }
        unless missing.empty?
          optional = parameters.count { |p| !p.value.nil? || p.captures_rest }
          raise ArgumentError, "Too few arguments; #{args_size} for #{optional > 0 ? ' min ' : ''}#{parameters_size - optional}"
        end
      end

      evaluated = merged.collect do |arg_assoc|
        # m can be one of
        # m = [Parameter{name => "name", value => nil], "given"]
        #   | [Parameter{name => "name", value => Expression}, "given"]
        #   | [Parameter{name => "name", value => Expression}, :missing]
        #
        # "given" may be nil or :undef which means that this is the value to use,
        # not a default expression.
        #

        # "given" is always present. If a parameter was provided then
        # the entry is that value, else the symbol :missing
        given_argument     = arg_assoc[1]
        argument_name      = arg_assoc[0].name
        param_captures     = arg_assoc[0].captures_rest
        default_expression = arg_assoc[0].value

        if given_argument == :missing
          # not given
          if default_expression
            # not given, has default
            value = @evaluator.evaluate(default_expression, scope)
            if param_captures && !value.is_a?(Array)
              # correct non array default value
              value = [ value ]
            end
          else
            # not given, does not have default
            if param_captures
              # default for captures rest is an empty array
              value = [ ]
            else
              # should have been caught earlier
              raise Puppet::DevError, "InternalError: Should not happen! non optional parameter not caught earlier in evaluator call"
            end
          end
        else
          # given
          if param_captures
            # get excess arguments
            value = args[(parameters_size-1)..-1]
            # If the input was a single nil, or undef, and there is a default, use the default
            if value.size == 1 && (given_argument.nil? || given_argument == :undef) && default_expression
              value = @evaluator.evaluate(default_expression, scope)
              # and ensure it is an array
              value = [value] unless value.is_a?(Array)
            end
          else
            # DEBATEABLE, since undef/nil selects default elsewhere (if changing, tests also needs changing).
            #          # Do not use given if there is a default and given is nil / undefined
            #          # else, let the value through
            #          if (given_argument.nil? || given_argument == :undef) && default_expression
            #            value = evaluate(default_expression, scope)
            #          else
            value = given_argument
            #          end
          end
        end
        [argument_name, value]
      end

      @evaluator.evaluate_block_with_bindings(@enclosing_scope, Hash[evaluated], @model.body)
    else
      raise ArgumentError, "lambda called with mis-matched arguments\n#{Puppet::Pops::Evaluator::CallableMismatchDescriber.diff_string('lambda', actual, [self])}"
    end
  end

  # Call closure with argument assignment by name
  def call_by_name(scope, args_hash, spill_over = false)
    parameters = @model.parameters || []

    if !spill_over && args_hash.size > parameters.size
      raise ArgumentError, "Too many arguments: #{args_hash.size} for #{parameters.size}"
    end

    # associate values with parameters
    scope_hash = {}
    parameters.each do |p|
      scope_hash[p.name] = args_hash[p.name] || @evaluator.evaluate(p.value, scope)
    end
    missing = scope_hash.reduce([]) {|memo, entry| memo << entry[0] if entry[1].nil?; memo }
    unless missing.empty?
      optional = parameters.count { |p| !p.value.nil? }
      raise ArgumentError, "Too few arguments; no value given for required parameters #{missing.join(" ,")}"
    end
    if spill_over
      # all args from given hash should be used, nil entries replaced by default values should win
      scope_hash = args_hash.merge(scope_hash)
    end

    @evaluator.evaluate_block_with_bindings(@enclosing_scope, scope_hash, @model.body)
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
    last = (@model.parameters || [])[-1]
    last && last.captures_rest
  end

  # @api public
  def block_name
    # TODO: Lambda's does not support blocks yet. This is a placeholder
    'unsupported_block'
  end

  private

  def create_callable_type()
    callable_type = parameters.collect do |param|
      if param.type_expr
        @evaluator.evaluate(param.type_expr, @enclosing_scope)
      else
        Puppet::Pops::Types::TypeFactory.optional_object()
      end
    end

    callable_type << optional_parameter_count
    callable_type << parameters.size

    Puppet::Pops::Types::TypeFactory.callable(*callable_type)
  end

  # Produces information about parameters compatible with a 4x Function (which can have multiple signatures)
  def signatures
    [ self ]
  end
end
