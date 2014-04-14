# The PuppetFunctionInstantiator instantiates a Puppet::Functions::Function given a Puppet Programming language
# source that when called evaluates the Puppet logic it contains.
#
class Puppet::Pops::Loader::PuppetFunctionInstantiator
  # Produces an instance of the Function class with the given typed_name, or fails with an error if the
  # given puppet source does not produce this instance when evaluated.
  #
  # @param loader [Puppet::Pops::Loader::Loader] The loader the function is associated with
  # @param typed_name [Puppet::Pops::Loader::TypedName] the type / name of the function to load
  # @param source_ref [URI, String] a reference to the source / origin of the puppet code to evaluate
  # @param pp_code_string [String] puppet code in a string
  #
  # @return [Puppet::Pops::Functions.Function] - an instantiated function with global scope closure associated with the given loader
  #
  def self.create(loader, typed_name, source_ref, pp_code_string)
    parser = Puppet::Pops::Parser::EvaluatingParser::Transitional.new()

    # parse and validate
    result = parser.parse_string(pp_code_string, source_ref)
    # Only one function is allowed (and no other definitions)
    case result.model.definitions.size
    when 0
      raise ArgumentError, "The code loaded from #{source_ref} does not define the function #{typed_name.name} - it is empty."
    when 1
      # ok
    else
      raise ArgumentError, "The code loaded from #{source_ref} must contain only the function #{typed_name.name} - it has additional definitions."
    end
    the_function_definition = result.model.definitions[0]

    unless the_function_definition.is_a?(Puppet::Pops::Model::FunctionDefinition)
      raise ArgumentError, "The code loaded from #{source_ref} does not define the function #{typed_name.name} - no function found."
    end
    unless the_function_definition.name == typed_name.name
      expected = typed_name.name
      actual = the_function_definition.name
      raise ArgumentError, "The code loaded from #{source_ref} produced function with the wrong name, expected #{expected}, actual #{actual}"
    end
    unless result.model().body == the_function_definition
      raise ArgumentError, "The code loaded from #{source_ref} contains additional logic - can only contain the function #{typed_name.name}"
    end

    # TODO: Cheating wrt. scope - assuming it is found in the context
    closure_scope = Puppet.lookup(:global_scope) { {} }

    created = create_function_class(the_function_definition, closure_scope)
    # create the function instance - it needs closure (scope), and loader (i.e. where it should start searching for things
    # when calling functions etc.
    # It should be bound to global scope

    created.new(closure_scope, loader)
  end

  def self.create_function_class(function_definition, closure_scope)
    method_name = :"#{function_definition.name.split(/::/).slice(-1)}"
    closure = Puppet::Pops::Evaluator::Closure.new(
      Puppet::Pops::Evaluator::EvaluatorImpl.new(),
        function_definition,
        closure_scope)
     required_optional = function_definition.parameters.reduce([0, 0]) do |memo, p|
       if p.value.nil?
         memo[0] += 1
       else
         memo[1] += 1
       end
       memo
     end
     min_arg_count = required_optional[0]
     max_arg_count = required_optional[0] + required_optional[1]

    # Create a 4x function wrapper around the Puppet Function
    created_function_class = Puppet::Functions.create_function(function_definition.name) do
      # Define the method that is called from dispatch - this method just changes a call
      # with multiple unknown arguments to passing all in an array (since this is expected in the closure API.
      #
      # TODO: The closure will call the evaluator.call method which will again match args with parameters.
      # This can be done a better way later - unifying the two concepts - a function instance is really the same
      # as the current evaluator closure for lambdas, only that it also binds an evaluator. This could perhaps
      # be a specialization of Function... with a special dispatch
      #
      define_method(:__relay__call__) do |*args|
        closure.call(nil, *args)
      end

      # Define a dispatch that performs argument type/count checking
      #
      dispatch :__relay__call__ do
        # Use Puppet Type Object (not Optional[Object] since the 3x API passes undef as empty string).
        param(optional(object), 'args')
        # Specify arg count (transformed from FunctionDefinition.parameters, no types, or varargs yet)
        arg_count(min_arg_count, max_arg_count)
      end
    end
    created_function_class

  end
end