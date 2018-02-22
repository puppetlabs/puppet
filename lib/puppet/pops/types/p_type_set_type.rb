module Puppet::Pops
module Types

KEY_NAME_AUTHORITY = 'name_authority'.freeze
KEY_TYPES = 'types'.freeze
KEY_ALIAS = 'alias'.freeze
KEY_VERSION = 'version'.freeze
KEY_VERSION_RANGE = 'version_range'.freeze
KEY_REFERENCES = 'references'.freeze

class PTypeSetType < PMetaType

  # A Loader that makes the types known to the TypeSet visible
  #
  # @api private
  class TypeSetLoader < Loader::BaseLoader
    def initialize(type_set, parent)
      super(parent, "(TypeSetFirstLoader '#{type_set.name}')")
      @type_set = type_set
    end

    def name_authority
      @type_set.name_authority
    end

    def model_loader
      @type_set.loader
    end

    def find(typed_name)
      if typed_name.type == :type && typed_name.name_authority == @type_set.name_authority
        type = @type_set[typed_name.name]
        return set_entry(typed_name, type) unless type.nil?
      end
      nil
    end
  end

  TYPE_STRING_OR_VERSION = TypeFactory.variant(PStringType::NON_EMPTY, TypeFactory.sem_ver)
  TYPE_STRING_OR_RANGE = TypeFactory.variant(PStringType::NON_EMPTY, TypeFactory.sem_ver_range)

  TYPE_TYPE_REFERENCE_I12N = TypeFactory.struct({
    KEY_NAME => Pcore::TYPE_QUALIFIED_REFERENCE,
    KEY_VERSION_RANGE => TYPE_STRING_OR_RANGE,
    TypeFactory.optional(KEY_NAME_AUTHORITY) => Pcore::TYPE_URI,
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS
  })

  TYPE_TYPESET_I12N = TypeFactory.struct({
    TypeFactory.optional(Pcore::KEY_PCORE_URI) => Pcore::TYPE_URI,
    Pcore::KEY_PCORE_VERSION => TYPE_STRING_OR_VERSION,
    TypeFactory.optional(KEY_NAME_AUTHORITY) => Pcore::TYPE_URI,
    TypeFactory.optional(KEY_NAME) => Pcore::TYPE_QUALIFIED_REFERENCE,
    TypeFactory.optional(KEY_VERSION) => TYPE_STRING_OR_VERSION,
    TypeFactory.optional(KEY_TYPES) => TypeFactory.hash_kv(Pcore::TYPE_SIMPLE_TYPE_NAME, PVariantType.new([PTypeType::DEFAULT, PObjectType::TYPE_OBJECT_I12N]), PCollectionType::NOT_EMPTY_SIZE),
    TypeFactory.optional(KEY_REFERENCES) => TypeFactory.hash_kv(Pcore::TYPE_SIMPLE_TYPE_NAME, TYPE_TYPE_REFERENCE_I12N, PCollectionType::NOT_EMPTY_SIZE),
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS,
  })

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType', '_pcore_init_hash' => TYPE_TYPESET_I12N.resolve(loader))
  end

  attr_reader :pcore_uri
  attr_reader :pcore_version
  attr_reader :name_authority
  attr_reader :name
  attr_reader :version
  attr_reader :types
  attr_reader :references
  attr_reader :annotations

  # Initialize a TypeSet Type instance. The initialization will use either a name and an initialization
  # hash expression, or a fully resolved initialization hash.
  #
  # @overload initialize(name, init_hash_expression)
  #   Used when the TypeSet type is loaded using a type alias expression. When that happens, it is important that
  #   the actual resolution of the expression is deferred until all definitions have been made known to the current
  #   loader. The package will then be resolved when it is loaded by the {TypeParser}. "resolved" here, means that
  #   the hash expression is fully resolved, and then passed to the {#_pcore_init_from_hash} method.
  #   @param name [String] The name of the type set
  #   @param init_hash_expression [Model::LiteralHash] The hash describing the TypeSet features
  #   @param name_authority [String] The default name authority for the type set
  #
  # @overload initialize(init_hash)
  #   Used when the package is created by the {TypeFactory}. The init_hash must be fully resolved.
  #   @param init_hash [Hash{String=>Object}] The hash describing the TypeSet features
  #
  # @api private
  def initialize(name_or_init_hash, init_hash_expression = nil, name_authority = nil)
    @types = EMPTY_HASH
    @references = EMPTY_HASH

    if name_or_init_hash.is_a?(Hash)
      _pcore_init_from_hash(name_or_init_hash)
    else
      # Creation using "type XXX = TypeSet[{}]". This means that the name is given
      @name = TypeAsserter.assert_instance_of('TypeSet name', Pcore::TYPE_QUALIFIED_REFERENCE, name_or_init_hash)
      @name_authority = TypeAsserter.assert_instance_of('TypeSet name_authority', Pcore::TYPE_URI, name_authority, true)
      @init_hash_expression = init_hash_expression
    end
  end

  # @api private
  def _pcore_init_from_hash(init_hash)
    TypeAsserter.assert_instance_of('TypeSet initializer', TYPE_TYPESET_I12N, init_hash)

    # Name given to the loader have higher precedence than a name declared in the type
    @name ||= init_hash[KEY_NAME].freeze
    @name_authority ||= init_hash[KEY_NAME_AUTHORITY].freeze

    @pcore_version = PSemVerType.convert(init_hash[Pcore::KEY_PCORE_VERSION]).freeze
    unless Pcore::PARSABLE_PCORE_VERSIONS.include?(@pcore_version)
      raise ArgumentError,
        "The pcore version for TypeSet '#{@name}' is not understood by this runtime. Expected range #{Pcore::PARSABLE_PCORE_VERSIONS}, got #{@pcore_version}"
    end

    @pcore_uri = init_hash[Pcore::KEY_PCORE_URI].freeze
    @version = PSemVerType.convert(init_hash[KEY_VERSION])
    @types = init_hash[KEY_TYPES] || EMPTY_HASH
    @types.freeze

    # Map downcase names to their camel-cased equivalent
    @dc_to_cc_map = {}
    @types.keys.each { |key| @dc_to_cc_map[key.downcase] = key }

    refs = init_hash[KEY_REFERENCES]
    if refs.nil?
      @references = EMPTY_HASH
    else
      ref_map = {}
      root_map = Hash.new { |h, k| h[k] = {} }
      refs.each do |ref_alias, ref|
        ref = TypeSetReference.new(self, ref)

        # Protect against importing the exact same name_authority/name combination twice if the version ranges intersect
        ref_name = ref.name
        ref_na = ref.name_authority || @name_authority
        na_roots = root_map[ref_na]

        ranges = na_roots[ref_name]
        if ranges.nil?
          na_roots[ref_name] = [ref.version_range]
        else
          unless ranges.all? { |range| (range & ref.version_range).nil? }
            raise ArgumentError, "TypeSet '#{@name}' references TypeSet '#{ref_na}/#{ref_name}' more than once using overlapping version ranges"
          end
          ranges << ref.version_range
        end

        if ref_map.has_key?(ref_alias)
          raise ArgumentError, "TypeSet '#{@name}' references a TypeSet using alias '#{ref_alias}' more than once"
        end
        if @types.has_key?(ref_alias)
          raise ArgumentError, "TypeSet '#{@name}' references a TypeSet using alias '#{ref_alias}'. The alias collides with the name of a declared type"
        end
        ref_map[ref_alias] = ref

        @dc_to_cc_map[ref_alias.downcase] = ref_alias
        ref_map[ref_alias] = ref
      end
      @references = ref_map.freeze
    end
    @dc_to_cc_map.freeze
    init_annotatable(init_hash)
  end

  # Produce a hash suitable for the initializer
  # @return [Hash{String => Object}] the initialization hash
  #
  # @api private
  def _pcore_init_hash
    result = super()
    result[Pcore::KEY_PCORE_URI] = @pcore_uri unless @pcore_uri.nil?
    result[Pcore::KEY_PCORE_VERSION] =  @pcore_version.to_s
    result[KEY_NAME_AUTHORITY] = @name_authority unless @name_authority.nil?
    result[KEY_NAME] = @name
    result[KEY_VERSION] = @version.to_s unless @version.nil?
    result[KEY_TYPES] = @types unless @types.empty?
    result[KEY_REFERENCES] = Hash[@references.map { |ref_alias, ref| [ref_alias, ref._pcore_init_hash] }] unless @references.empty?
    result
  end

  # Resolve a type in this type set using a qualified name. The resolved type may either be a type defined in this type set
  # or a type defined in a type set that is referenced by this type set (nesting may occur to any level).
  # The name resolution is case insensitive.
  #
  # @param qname [String,Loader::TypedName] the qualified name of the type to resolve
  # @return [PAnyType,nil] the resolved type, or `nil` in case no type could be found
  #
  # @api public
  def [](qname)
    if qname.is_a?(Loader::TypedName)
      return nil unless qname.type == :type && qname.name_authority == @name_authority
      qname = qname.name
    end

    type = @types[qname] || @types[@dc_to_cc_map[qname.downcase]]
    if type.nil? && !@references.empty?
      segments = qname.split(TypeFormatter::NAME_SEGMENT_SEPARATOR)
      first = segments[0]
      type_set_ref = @references[first] || @references[@dc_to_cc_map[first.downcase]]
      if type_set_ref.nil?
        nil
      else
        type_set = type_set_ref.type_set
        case segments.size
        when 1
          type_set
        when 2
          type_set[segments[1]]
        else
          segments.shift
          type_set[segments.join(TypeFormatter::NAME_SEGMENT_SEPARATOR)]
        end
      end
    else
      type
    end
  end

  def defines_type?(t)
    !@types.key(t).nil?
  end

  # Returns the name by which the given type is referenced from within this type set
  # @param t [PAnyType]
  # @return [String] the name by which the type is referenced within this type set
  #
  # @api private
  def name_for(t, default_name)
    key = @types.key(t)
    if key.nil?
      if @references.empty?
        default_name
      else
        @references.each_pair do |ref_key, ref|
          ref_name = ref.type_set.name_for(t, nil)
          return "#{ref_key}::#{ref_name}" unless ref_name.nil?
        end
        default_name
      end
    else
      key
    end
  end

  def accept(visitor, guard)
    super
    @types.each_value { |type| type.accept(visitor, guard) }
    @references.each_value { |ref| ref.accept(visitor, guard) }
  end

  # @api private
  def label
    "TypeSet '#{@name}'"
  end

  # @api private
  def resolve(loader)
    super
    @references.each_value { |ref| ref.resolve(loader) }
    tsa_loader = TypeSetLoader.new(self, loader)
    @types.values.each { |type| type.resolve(tsa_loader) }
    self
  end

  # @api private
  def resolve_literal_hash(loader, init_hash_expression)
    result = {}
    type_parser = TypeParser.singleton
    init_hash_expression.entries.each do |entry|
      key = type_parser.interpret_any(entry.key, loader)
      if (key == KEY_TYPES || key == KEY_REFERENCES) && entry.value.is_a?(Model::LiteralHash)
        # Skip type parser interpretation and convert qualified references directly to String keys.
        hash = {}
        entry.value.entries.each do |he|
          kex = he.key
          name = kex.is_a?(Model::QualifiedReference) ? kex.cased_value : type_parser.interpret_any(kex, loader)
          hash[name] = key == KEY_TYPES ? he.value : type_parser.interpret_any(he.value, loader)
        end
        result[key] = hash
      else
        result[key] = type_parser.interpret_any(entry.value, loader)
      end
    end

    name_auth = resolve_name_authority(result, loader)

    types = result[KEY_TYPES]
    if types.is_a?(Hash)
      types.each do |type_name, value|
        full_name = "#{@name}::#{type_name}".freeze
        typed_name = Loader::TypedName.new(:type, full_name, name_auth)
        if value.is_a?(Model::ResourceDefaultsExpression)
          # This is actually a <Parent> { <key-value entries> } notation. Convert to a literal hash that contains the parent
          n = value.type_ref
          name = n.cased_value
          entries = []
          unless name == 'Object' or name == 'TypeSet'
            if value.operations.any? { |op| op.attribute_name == KEY_PARENT }
              case Puppet[:strict]
              when :warning
                IssueReporter.warning(value, Issues::DUPLICATE_KEY, :key => KEY_PARENT)
              when :error
                IssueReporter.error(Puppet::ParseErrorWithIssue, value, Issues::DUPLICATE_KEY, :key => KEY_PARENT)
              end
            end
            entries << Model::KeyedEntry.new(n.locator, n.offset, n.length, KEY_PARENT, n)
          end
          value.operations.each { |op| entries << Model::KeyedEntry.new(op.locator, op.offset, op.length, op.attribute_name, op.value_expr) }
          value = Model::LiteralHash.new(value.locator, value.offset, value.length, entries)
        end
        type = Loader::TypeDefinitionInstantiator.create_type(full_name, value, name_auth)
        loader.set_entry(typed_name, type, value.locator.to_uri(value))
        types[type_name] = type
      end
    end
    result
  end

  # @api private
  def resolve_hash(loader, init_hash)
    result = Hash[init_hash.map do |key, value|
      key = resolve_type_refs(loader, key)
      value = resolve_type_refs(loader, value) unless key == KEY_TYPES && value.is_a?(Hash)
      [key, value]
    end]
    name_auth = resolve_name_authority(result, loader)
    types = result[KEY_TYPES]
    if types.is_a?(Hash)
      types.each do |type_name, value|
        full_name = "#{@name}::#{type_name}".freeze
        typed_name = Loader::TypedName.new(:type, full_name, name_auth)
        meta_name = value.is_a?(Hash) ? 'Object' : 'TypeAlias'
        type = Loader::TypeDefinitionInstantiator.create_named_type(full_name, meta_name, value, name_auth)
        loader.set_entry(typed_name, type)
        types[type_name] = type
      end
    end
    result
  end

  def hash
    @name_authority.hash ^ @name.hash ^ @version.hash
  end

  def eql?(o)
    self.class == o.class && @name_authority == o.name_authority && @name == o.name && @version == o.version
  end

  DEFAULT = self.new({
    KEY_NAME => 'DefaultTypeSet',
    KEY_NAME_AUTHORITY => Pcore::RUNTIME_NAME_AUTHORITY,
    Pcore::KEY_PCORE_URI => Pcore::PCORE_URI,
    Pcore::KEY_PCORE_VERSION => Pcore::PCORE_VERSION,
    KEY_VERSION => SemanticPuppet::Version.new(0,0,0)
  })

  protected

  # @api_private
  def _assignable?(o, guard)
    self.class == o.class && (self == DEFAULT || eql?(o))
  end

  private

  def resolve_name_authority(init_hash, loader)
    name_auth = @name_authority
    if name_auth.nil?
      name_auth = init_hash[KEY_NAME_AUTHORITY]
      name_auth = loader.name_authority if name_auth.nil? && loader.is_a?(TypeSetLoader)
      if name_auth.nil?
        name = @name || init_hash[KEY_NAME]
        raise ArgumentError, "No 'name_authority' is declared in TypeSet '#{name}' and it cannot be inferred"
      end
    end
    name_auth
  end
end
end
end
