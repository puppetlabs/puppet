# The RubyLegacyFunctionInstantiator instantiates a Puppet::Functions::Function given the ruby source
# that calls Puppet::Functions.create_function.
#
class Puppet::Pops::Loader::RubyLegacyFunctionInstantiator
  # Produces an instance of the Function class with the given typed_name, or fails with an error if the
  # given ruby source does not produce this instance when evaluated.
  #
  # @param loader [Puppet::Pops::Loader::Loader] The loader the function is associated with
  # @param typed_name [Puppet::Pops::Loader::TypedName] the type / name of the function to load
  # @param source_ref [URI, String] a reference to the source / origin of the ruby code to evaluate
  # @param ruby_code_string [String] ruby code in a string
  #
  # @return [Puppet::Pops::Functions.Function] - an instantiated function with global scope closure associated with the given loader
  #
  def self.create(loader, typed_name, source_ref, ruby_code_string)
    unless ruby_code_string.is_a?(String) && ruby_code_string =~ /Puppet\:\:Parser\:\:Functions.*newfunction/m
      raise ArgumentError, _("The code loaded from %{source_ref} does not seem to be a Puppet 3x API function - no 'newfunction' call.") % { source_ref: source_ref }
    end
    # make the private loader available in a binding to allow it to be passed on
    loader_for_function = loader.private_loader
    here = get_binding(loader_for_function)

    # Avoid reloading the function if already loaded via one of the APIs that trigger 3x function loading
    # Check if function is already loaded the 3x way (and obviously not the 4x way since we would not be here in the
    # first place.
    environment = Puppet.lookup(:current_environment)
    func_info = Puppet::Parser::Functions.environment_module(environment).get_function_info(typed_name.name.to_sym)
    if func_info.nil?
      # This will to do the 3x loading and define the "function_<name>" and "real_function_<name>" methods
      # in the anonymous module used to hold function definitions.
      #
      func_info = eval(ruby_code_string, here, source_ref, 1)

      # Validate what was loaded
      unless func_info.is_a?(Hash)
        raise ArgumentError, _("The code loaded from %{source_ref} did not produce the expected 3x function info Hash when evaluated. Got '%{klass}'") % { source_ref: source_ref, klass: created.class }
      end
      unless func_info[:name] == "function_#{typed_name.name()}"
        raise ArgumentError, _("The code loaded from %{source_ref} produced mis-matched name, expected 'function_%{type_name}', got %{created_name}") % { 
          source_ref: source_ref, type_name: typed_name.name, created_name: func_info[:name] }
      end
    end

    created = Puppet::Functions::Function3x.create_function(typed_name.name(), func_info, loader_for_function)

    # create the function instance - it needs closure (scope), and loader (i.e. where it should start searching for things
    # when calling functions etc.
    # It should be bound to global scope

    # Sets closure scope to nil, to let it be picked up at runtime from Puppet.lookup(:global_scope)
    # If function definition used the loader from the binding to create a new loader, that loader wins
    created.new(nil, loader_for_function)
  end

  # Produces a binding where the given loader is bound as a local variable (loader_injected_arg). This variable can be used in loaded
  # ruby code - e.g. to call Puppet::Function.create_loaded_function(:name, loader,...)
  #
  def self.get_binding(loader_injected_arg)
    binding
  end
  private_class_method :get_binding
end
