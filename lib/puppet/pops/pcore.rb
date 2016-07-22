require 'uri'

module Puppet::Pops
module Pcore
  TYPE_URI_RX = Types::TypeFactory.regexp(URI.regexp)
  TYPE_URI = Types::TypeFactory.pattern(TYPE_URI_RX)
  TYPE_SIMPLE_TYPE_NAME = Types::TypeFactory.pattern(/\A[A-Z]\w*\z/)
  TYPE_QUALIFIED_REFERENCE = Types::TypeFactory.pattern(/\A[A-Z][\w]*(?:::[A-Z][\w]*)*\z/)

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
    Types::TypedModelObject.register_ptypes(loader, ir)

    ir.register_implementation_namespace('Pcore', 'Puppet::Pops::Pcore', loader)
    ir.register_implementation_namespace('Puppet::AST', 'Puppet::Pops::Model', loader)
    ast_type_set = Serialization::RGen::TypeGenerator.new.generate_type_set('Puppet::AST', Puppet::Pops::Model, loader)

    # Extend the Puppet::AST type set with the Locator (it's not an RGen class, but nevertheless, used in the model)
    ast_ts_i12n = ast_type_set.i12n_hash
    ast_ts_i12n['types'] = ast_ts_i12n['types'].merge('Locator' => Parser::Locator::Locator19.register_ptype(loader, ir))
    add_type(Types::PTypeSetType.new(ast_ts_i12n), loader)

    Resource.register_ptypes(loader, ir)
  end

  # Create and register a new `Object` type in the Puppet Type System and map it to an implementation class
  #
  # @param loader [Loader::Loader] The loader where the new type will be registered
  # @param ir [ImplementationRegistry] The implementation registry that maps this class to the new type
  # @param impl_class [Class] The class that is the implementation of the type
  # @param type_name [String] The fully qualified name of the new type
  # @param parent_name [String,nil] The fully qualified name of the parent type
  # @param attributes_hash [Hash{String => Object}] A hash of attribute definitions for the new type
  # @param functions_hash [Hash{String => Object}] A hash of function definitions for the new type
  # @param equality [Array<String>] An array with names of attributes that participate in equality comparison
  # @return [PObjectType] the created type. Not yet resolved
  #
  # @api private
  def self.create_object_type(loader, ir, impl_class, type_name, parent_name, attributes_hash = EMPTY_HASH, functions_hash = EMPTY_HASH, equality = nil)
    i12n_hash = {}
    i12n_hash[Types::KEY_PARENT] = Types::PTypeReferenceType.new(parent_name) unless parent_name.nil?
    i12n_hash[Types::KEY_ATTRIBUTES] = attributes_hash unless attributes_hash.empty?
    i12n_hash[Types::KEY_FUNCTIONS] = functions_hash unless functions_hash.empty?
    i12n_hash[Types::KEY_EQUALITY] = equality unless equality.nil?
    ir.register_implementation(type_name, impl_class, loader)
    add_type(Types::PObjectType.new(type_name, i12n_hash), loader)
  end

  def self.add_object_type(name, body, loader)
    add_type(Types::PObjectType.new(name, Parser::EvaluatingParser.new.parse_string(body).current.body), loader)
  end

  def self.add_alias(name, type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    add_type(Types::PTypeAliasType.new(name, nil, type), loader, name_authority)
  end

  def self.add_type(type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    loader.set_entry(Loader::TypedName.new(:type, type.name.downcase, name_authority), type)
    type
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
