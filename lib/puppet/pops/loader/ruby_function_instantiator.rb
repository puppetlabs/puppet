# frozen_string_literal: true
# The RubyFunctionInstantiator instantiates a Puppet::Functions::Function given the ruby source
# that calls Puppet::Functions.create_function.
#
class Puppet::Pops::Loader::RubyFunctionInstantiator
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
    unless ruby_code_string.is_a?(String) && ruby_code_string =~ /Puppet\:\:Functions\.create_function/
      raise ArgumentError, _("The code loaded from %{source_ref} does not seem to be a Puppet 4x API function - no create_function call.") % { source_ref: source_ref }
    end

    # make the private loader available in a binding to allow it to be passed on
    loader_for_function = loader.private_loader
    here = get_binding(loader_for_function)
    created = eval(ruby_code_string, here, source_ref, 1) # rubocop:disable Security/Eval
    unless created.is_a?(Class)
      raise ArgumentError, _("The code loaded from %{source_ref} did not produce a Function class when evaluated. Got '%{klass}'") % { source_ref: source_ref, klass: created.class }
    end
    unless created.name.to_s == typed_name.name()
      raise ArgumentError, _("The code loaded from %{source_ref} produced mis-matched name, expected '%{type_name}', got %{created_name}") % { source_ref: source_ref, type_name: typed_name.name, created_name: created.name }
    end

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
