module Puppet::Pops
module Loader

# Runtime3TypeLoader
# ===
# Loads a resource type using the 3.x type loader
#
# @api private
class Runtime3TypeLoader < BaseLoader
  def initialize(parent_loader, environment)
    super(parent_loader, environment.name)
    @environment = environment
  end

  def to_s()
    "(Runtime3TypeLoader '#{loader_name()}')"
  end

  # Finds typed/named entity in this module
  # @param typed_name [TypedName] the type/name to find
  # @return [Loader::NamedEntry, nil found/created entry, or nil if not found
  #
  def find(typed_name)
    return nil unless typed_name.type == :type

    name = typed_name.name
    value = @environment.known_resource_types.find_definition(name)
    if value.nil?
      # Look for Puppet::Type
      value = Puppet::Type.type(name)
      if value.nil?
        # Cache the fact that it wasn't found
        set_entry(typed_name, nil)
        return nil
      end
    end

    # Loaded types doesn't have the same life cycle as this loader, so we must start by
    # checking if the type was created. If it was, an entry will already be stored in
    # this loader. If not, then it was created before this loader was instantiated and
    # we must therefore add it.
    te = get_entry(typed_name)
    te = set_entry(typed_name, Types::TypeFactory.resource(value.name.to_s)) if te.nil? || te.value.nil?
    te
  end

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
