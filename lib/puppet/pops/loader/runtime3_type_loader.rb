module Puppet::Pops
module Loader

# Runtime3TypeLoader
# ===
# Loads a resource type using the 3.x type loader
#
# @api private
class Runtime3TypeLoader < BaseLoader
  def initialize(parent_loader, environment, env_path)
    super(parent_loader, environment.name)
    @environment = environment
    @resource_3x_loader = env_path.nil? ? nil : ModuleLoaders.module_loader_from(parent_loader, self, 'environment', env_path)
  end

  def to_s()
    "(Runtime3TypeLoader '#{loader_name()}')"
  end

  # Finds typed/named entity in this module
  # @param typed_name [TypedName] the type/name to find
  # @return [Loader::NamedEntry, nil found/created entry, or nil if not found
  #
  def find(typed_name)
    return nil unless typed_name.name_authority == Pcore::RUNTIME_NAME_AUTHORITY
    case typed_name.type
    when :type
      value = nil
      name = typed_name.name
      if @resource_3x_loader.nil?
        value = Puppet::Type.type(name) unless typed_name.qualified?
        if value.nil?
          # Look for a user defined type
          value = @environment.known_resource_types.find_definition(name)
        end
      else
        impl_te = find_impl(TypedName.new(:resource_type_pp, name, typed_name.name_authority))
        value = impl_te.value unless impl_te.nil?
      end

      if value.nil?
        # Cache the fact that it wasn't found
        set_entry(typed_name, nil)
        return nil
      end

      # Loaded types doesn't have the same life cycle as this loader, so we must start by
      # checking if the type was created. If it was, an entry will already be stored in
      # this loader. If not, then it was created before this loader was instantiated and
      # we must therefore add it.
      te = get_entry(typed_name)
      te = set_entry(typed_name, Types::TypeFactory.resource(value.name.to_s)) if te.nil? || te.value.nil?
      te
    when :resource_type_pp
      @resource_3x_loader.nil? ? nil : find_impl(typed_name)
    else
      nil
    end
  end

  # Find the implementation for the resource type by first consulting the internal loader for pp defined 'Puppet::Resource::ResourceType3'
  # instances, then check for a Puppet::Type and lastly check for a defined type.
  #
  def find_impl(typed_name)
    name = typed_name.name
    te = StaticLoader::BUILTIN_TYPE_NAMES_LC.include?(name) ? nil : @resource_3x_loader.find(typed_name)
    if te.nil? || te.value.nil?
      # Look for Puppet::Type
      value = Puppet::Type.type(name) unless typed_name.qualified?
      if value.nil?
        # Look for a user defined type
        value = @environment.known_resource_types.find_definition(name)
        if value.nil?
          # Cache the fact that it wasn't found
          @resource_3x_loader.set_entry(typed_name, nil)
          return nil
        end
      end
      te = @resource_3x_loader.get_entry(typed_name)
      te = @resource_3x_loader.set_entry(typed_name, value) if te.nil? || te.value.nil?
    end
    te
  end
  private :find_impl

  # Allows shadowing since this loader is populalted with all loaded resource types at time
  # of loading. This loading will, for built in types override the aliases configured in the static
  # loader.
  #
  def allow_shadowing?
    true
  end

end
end
end
