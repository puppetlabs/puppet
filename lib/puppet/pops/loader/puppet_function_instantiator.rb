module Puppet::Pops
module Loader
# The PuppetFunctionInstantiator instantiates a Puppet::Functions::PuppetFunction given a Puppet Programming language
# source that when called evaluates the Puppet logic it contains.
#
class PuppetFunctionInstantiator
  # Produces an instance of the Function class with the given typed_name, or fails with an error if the
  # given puppet source does not produce this instance when evaluated.
  #
  # @param loader [Loader] The loader the function is associated with
  # @param typed_name [TypedName] the type / name of the function to load
  # @param source_ref [URI, String] a reference to the source / origin of the puppet code to evaluate
  # @param pp_code_string [String] puppet code in a string
  #
  # @return [Functions::Function] - an instantiated function with global scope closure associated with the given loader
  #
  def self.create(loader, typed_name, source_ref, pp_code_string)
    parser = Parser::EvaluatingParser.new()

    # parse and validate
    result = parser.parse_string(pp_code_string, source_ref)
    # Only one function is allowed (and no other definitions)
    case result.definitions.size
    when 0
      raise ArgumentError, _("The code loaded from %{source_ref} does not define the function '%{func_name}' - it is empty.") % { source_ref: source_ref, func_name: typed_name.name }
    when 1
      # ok
    else
      raise ArgumentError, _("The code loaded from %{source_ref} must contain only the function '%{type_name}' - it has additional definitions.") % { source_ref: source_ref, type_name: typed_name.name }
    end
    the_function_definition = result.definitions[0]

    unless the_function_definition.is_a?(Model::FunctionDefinition)
      raise ArgumentError, _("The code loaded from %{source_ref} does not define the function '%{type_name}' - no function found.") % { source_ref: source_ref, type_name: typed_name.name }
    end
    unless the_function_definition.name == typed_name.name
      expected = typed_name.name
      actual = the_function_definition.name
      raise ArgumentError, _("The code loaded from %{source_ref} produced function with the wrong name, expected %{expected}, actual %{actual}") % { source_ref: source_ref, expected: expected, actual: actual }
    end
    unless result.body == the_function_definition
      raise ArgumentError, _("The code loaded from %{source} contains additional logic - can only contain the function %{name}") % { source: source_ref, name: typed_name.name }
    end

    # Adapt the function definition with loader - this is used from logic contained in it body to find the
    # loader to use when making calls to the new function API. Such logic have a hard time finding the closure (where
    # the loader is known - hence this mechanism
    private_loader = loader.private_loader
    Adapters::LoaderAdapter.adapt(the_function_definition).loader_name = private_loader.loader_name

    # Cannot bind loaded functions to global scope, that must be done without binding that scope as
    # loaders survive a compilation.
    closure_scope = nil # Puppet.lookup(:global_scope) { {} }

    created = create_function_class(the_function_definition)
    # create the function instance - it needs closure (scope), and loader (i.e. where it should start searching for things
    # when calling functions etc.
    # It should be bound to global scope

    created.new(closure_scope, private_loader)
  end

  # Creates Function class and instantiates it based on a FunctionDefinition model
  # @return [Array<TypedName, Functions.Function>] - array of
  #   typed name, and an instantiated function with global scope closure associated with the given loader
  #
  def self.create_from_model(function_definition, loader)
    created = create_function_class(function_definition)
    typed_name = TypedName.new(:function, function_definition.name)
    [typed_name, created.new(nil, loader)]
  end

  def self.create_function_class(function_definition)
    # Create a 4x function wrapper around a named closure
    Puppet::Functions.create_function(function_definition.name, Puppet::Functions::PuppetFunction) do
      # TODO: should not create a new evaluator per function
      init_dispatch(Evaluator::Closure::Named.new(
        function_definition.name,
        Evaluator::EvaluatorImpl.new(), function_definition))
    end
  end
end
end
end
