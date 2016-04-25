require 'uri'

module Puppet::Pops
module Pcore
  TYPE_QUALIFIED_REFERENCE = Types::TypeFactory.pattern(Types::TypeFactory.regexp(Patterns::CLASSREF_EXT))

  def self.init(loader, ir)
    add_alias('Puppet::Pcore::QualifiedReference', TYPE_QUALIFIED_REFERENCE, loader)

    ir.register_implementation_namespace('Puppet::Pcore', 'Puppet::Pops::Pcore', loader)
  end

  def self.add_alias(name, type, loader)
    add_type(Types::PTypeAliasType.new(name, nil, type), loader)
  end

  def self.add_type(type, loader)
    loader.set_entry(Loader::Loader::TypedName.new(:type, type.name.downcase), type)
  end

  def self.register_implementations(*impls)
    Loaders.loaders.register_implementations(*impls)
  end

  def self.register_aliases(aliases)
    loader = Loaders.loaders.private_environment_loader
    aliases.each { |name, type_string| add_type(Types::PTypeAliasType.new(name, Types::TypeFactory.type_reference(type_string), nil), loader) }
  end
end
end
