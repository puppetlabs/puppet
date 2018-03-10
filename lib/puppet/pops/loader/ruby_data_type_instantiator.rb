# The RubyTypeInstantiator instantiates a data type from the ruby source
# that calls Puppet::DataTypes.create_type.
#
class Puppet::Pops::Loader::RubyDataTypeInstantiator
  # Produces an instance of class derived from PAnyType class with the given typed_name, or fails with an error if the
  # given ruby source does not produce this instance when evaluated.
  #
  # @param loader [Puppet::Pops::Loader::Loader] The loader the type is associated with
  # @param typed_name [Puppet::Pops::Loader::TypedName] the type / name of the type to load
  # @param source_ref [URI, String] a reference to the source / origin of the ruby code to evaluate
  # @param ruby_code_string [String] ruby code in a string
  #
  # @return [Puppet::Pops::Types::PAnyType] - an instantiated data type associated with the given loader
  #
  def self.create(loader, typed_name, source_ref, ruby_code_string)
    unless ruby_code_string.is_a?(String) && ruby_code_string =~ /Puppet\:\:DataTypes\.create_type/
      raise ArgumentError, _("The code loaded from %{source_ref} does not seem to be a Puppet 5x API data type - no create_type call.") % { source_ref: source_ref }
    end
    # make the private loader available in a binding to allow it to be passed on
    loader_for_type = loader.private_loader
    here = get_binding(loader_for_type)
    created = eval(ruby_code_string, here, source_ref, 1)
    unless created.is_a?(Puppet::Pops::Types::PAnyType)
      raise ArgumentError, _("The code loaded from %{source_ref} did not produce a data type when evaluated. Got '%{klass}'") % { source_ref: source_ref, klass: created.class }
    end
    unless created.name.casecmp(typed_name.name) == 0
      raise ArgumentError, _("The code loaded from %{source_ref} produced mis-matched name, expected '%{type_name}', got %{created_name}") % { source_ref: source_ref, type_name: typed_name.name, created_name: created.name }
    end
    created
  end

  # Produces a binding where the given loader is bound as a local variable (loader_injected_arg). This variable can be used in loaded
  # ruby code - e.g. to call Puppet::Function.create_loaded_function(:name, loader,...)
  #
  def self.get_binding(loader_injected_arg)
    binding
  end
  private_class_method :get_binding
end
