require 'uri'

module Puppet::Pops
module Pcore
  TYPE_URI_RX = Types::TypeFactory.regexp(URI.regexp)
  TYPE_URI = Types::TypeFactory.pattern(TYPE_URI_RX)
  TYPE_SIMPLE_TYPE_NAME = Types::TypeFactory.pattern(/[A-Z]\w*/)
  TYPE_QUALIFIED_REFERENCE = Types::TypeFactory.pattern(Types::TypeFactory.regexp(Patterns::CLASSREF_EXT))

  KEY_PCORE_URI = 'pcore_uri'.freeze
  KEY_PCORE_VERSION = 'pcore_version'.freeze

  PCORE_URI = 'http://puppet.com/2016.1/pcore'
  PCORE_VERSION = Semantic::Version.new(1,0,0)
  PARSABLE_PCORE_VERSIONS = Semantic::VersionRange.parse('1.x')

  RUNTIME_NAME_AUTHORITY = 'http://puppet.com/2016.1/runtime'

  def self.init(loader, ir)
    add_alias('Pcore::URI_RX', TYPE_URI_RX, loader)
    add_alias('Pcore::URI', TYPE_URI, loader)
    add_alias('Pcore::SimpleTypeName', TYPE_SIMPLE_TYPE_NAME, loader)
    add_alias('Pcore::TypeName', TYPE_QUALIFIED_REFERENCE, loader)
    add_alias('Pcore::QRef', TYPE_QUALIFIED_REFERENCE, loader)

    ir.register_implementation_namespace('Pcore', 'Puppet::Pops::Pcore', loader)
  end

  def self.add_object(name, body, loader)
    add_type(Types::PObjectType.new(name, Parser::EvaluatingParser.new.parse_string(body).current.body), loader)
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
    aliases.each do |name, type_string|
      add_type(Types::PTypeAliasType.new(name, Types::TypeFactory.type_reference(type_string), nil), loader, name_authority)
    end
  end
end
end
