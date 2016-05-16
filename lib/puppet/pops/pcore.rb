require 'uri'

module Puppet::Pops
module Pcore
  TYPE_QUALIFIED_REFERENCE = Types::TypeFactory.pattern(Types::TypeFactory.regexp(Patterns::CLASSREF_EXT))

  RUNTIME_NAME_AUTHORITY = 'http://puppet.com/2016.1/runtime'

  def self.init(loader, ir)
    add_alias('Puppet::Pcore::QualifiedReference', TYPE_QUALIFIED_REFERENCE, loader)

    ir.register_implementation_namespace('Puppet::Pcore', 'Puppet::Pops::Pcore', loader)
  end

  def self.add_alias(name, type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    add_type(Types::PTypeAliasType.new(name, nil, type), loader, name_authority)
  end

  def self.add_type(type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    loader.set_entry(Loader::TypedName.new(:type, type.name.downcase, name_authority), type)
  end

  def self.register_implementations(impls, name_authority = RUNTIME_NAME_AUTHORITY)
    Loaders.loaders.register_implementations(impls, name_authority = RUNTIME_NAME_AUTHORITY)
  end

  def self.register_aliases(aliases, name_authority = RUNTIME_NAME_AUTHORITY)
    loader = Loaders.loaders.private_environment_loader
    aliases.each { |name, type_string| add_type(
      Types::PTypeAliasType.new(name, Types::TypeFactory.type_reference(type_string), nil), loader, name_authority) }
  end
end
end
