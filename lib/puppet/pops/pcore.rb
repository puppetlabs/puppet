require 'uri'

module Puppet::Pops
module Pcore
  include Types::PuppetObject

  TYPE_URI_RX = Types::TypeFactory.regexp(URI.regexp)
  TYPE_URI = Types::TypeFactory.pattern(TYPE_URI_RX)
  TYPE_URI_ALIAS = Types::PTypeAliasType.new('Pcore::URI', nil, TYPE_URI)
  TYPE_SIMPLE_TYPE_NAME = Types::TypeFactory.pattern(/\A[A-Z]\w*\z/)
  TYPE_QUALIFIED_REFERENCE = Types::TypeFactory.pattern(/\A[A-Z][\w]*(?:::[A-Z][\w]*)*\z/)
  TYPE_MEMBER_NAME = Types::PPatternType.new([Types::PRegexpType.new(Patterns::PARAM_NAME)])

  KEY_PCORE_URI = 'pcore_uri'.freeze
  KEY_PCORE_VERSION = 'pcore_version'.freeze

  PCORE_URI = 'http://puppet.com/2016.1/pcore'
  PCORE_VERSION = SemanticPuppet::Version.new(1,0,0)
  PARSABLE_PCORE_VERSIONS = SemanticPuppet::VersionRange.parse('1.x')

  RUNTIME_NAME_AUTHORITY = 'http://puppet.com/2016.1/runtime'

  def self._pcore_type
    @type
  end

  def self.annotate(instance, annotations_hash)
    annotations_hash.each_pair do |type, init_hash|
      type.implementation_class.annotate(instance) { init_hash }
    end
    instance
  end

  def self.init_env(loader)
    if Puppet[:tasks]
      add_object_type('Task', <<-PUPPET, loader)
        {
          attributes => {   
            # Fully qualified name of the task
            name => { type => Pattern[/\\A[a-z][a-z0-9_]*(?:::[a-z][a-z0-9_]*)*\\z/] },

            # Full path to executable
            executable => { type => String },

            # Task description
            description => { type => Optional[String], value => undef },

            # Puppet Task version
            puppet_task_version => { type => Integer, value => 1 },
  
            # Type, description, and sensitive property of each parameter 
            parameters => {
              type => Optional[Hash[
                Pattern[/\\A[a-z][a-z0-9_]*\\z/],
                Struct[
                  Optional[description] => String,
                  Optional[sensitive] => Boolean,
                  type => Type]]],
              value => undef
            },

             # Type, description, and sensitive property of each output 
            output => {
              type => Optional[Hash[
                Pattern[/\\A[a-z][a-z0-9_]*\\z/],
                Struct[
                  Optional[description] => String,
                  Optional[sensitive] => Boolean,
                  type => Type]]],
              value => undef
            },
 
            supports_noop => { type => Boolean, value => false },
            input_method => { type => String, value => 'both' },
          }
        }
      PUPPET
    end
  end

  def self.init(loader, ir)
    add_alias('Pcore::URI_RX', TYPE_URI_RX, loader)
    add_type(TYPE_URI_ALIAS, loader)
    add_alias('Pcore::SimpleTypeName', TYPE_SIMPLE_TYPE_NAME, loader)
    add_alias('Pcore::MemberName', TYPE_MEMBER_NAME, loader)
    add_alias('Pcore::TypeName', TYPE_QUALIFIED_REFERENCE, loader)
    add_alias('Pcore::QRef', TYPE_QUALIFIED_REFERENCE, loader)
    Types::TypedModelObject.register_ptypes(loader, ir)

    @type = create_object_type(loader, ir, Pcore, 'Pcore', nil)

    ir.register_implementation_namespace('Pcore', 'Puppet::Pops::Pcore')
    ir.register_implementation_namespace('Puppet::AST', 'Puppet::Pops::Model')
    ir.register_implementation('Puppet::AST::Locator', 'Puppet::Pops::Parser::Locator::Locator19')
    Resource.register_ptypes(loader, ir)
    Lookup::Context.register_ptype(loader, ir);
    Lookup::DataProvider.register_types(loader)
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
    init_hash = {}
    init_hash[Types::KEY_PARENT] = Types::PTypeReferenceType.new(parent_name) unless parent_name.nil?
    init_hash[Types::KEY_ATTRIBUTES] = attributes_hash unless attributes_hash.empty?
    init_hash[Types::KEY_FUNCTIONS] = functions_hash unless functions_hash.empty?
    init_hash[Types::KEY_EQUALITY] = equality unless equality.nil?
    ir.register_implementation(type_name, impl_class)
    add_type(Types::PObjectType.new(type_name, init_hash), loader)
  end

  def self.add_object_type(name, body, loader)
    add_type(Types::PObjectType.new(name, Parser::EvaluatingParser.new.parse_string(body).body), loader)
  end

  def self.add_alias(name, type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    add_type(Types::PTypeAliasType.new(name, nil, type), loader, name_authority)
  end

  def self.add_type(type, loader, name_authority = RUNTIME_NAME_AUTHORITY)
    loader.set_entry(Loader::TypedName.new(:type, type.name, name_authority), type)
    type
  end

  def self.register_implementations(impls, name_authority = RUNTIME_NAME_AUTHORITY)
    Loaders.loaders.register_implementations(impls, name_authority)
  end

  def self.register_aliases(aliases, name_authority = RUNTIME_NAME_AUTHORITY, loader = Loaders.loaders.private_environment_loader)
    aliases.each do |name, type_string|
      add_type(Types::PTypeAliasType.new(name, Types::TypeFactory.type_reference(type_string), nil), loader, name_authority)
    end
    aliases.each_key.map { |name| loader.load(:type, name).resolve(loader) }
  end
end
end
