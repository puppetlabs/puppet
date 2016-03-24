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
    if typed_name.type == :type
      name = typed_name.name
      value = @environment.known_resource_types.find_definition(name)
      set_entry(typed_name, Types::TypeFactory.resource(name.capitalize)) unless value.nil?
    else
      nil
    end
  end
end
end
end
