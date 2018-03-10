module Puppet::Pops
module Types
# Helper module that makes creation of type objects simpler.
# @api public
#
module TypeFactory
  @type_calculator = TypeCalculator.singleton

  # Produces the Integer type
  # @api public
  #
  def self.integer
    PIntegerType::DEFAULT
  end

  # Produces an Integer range type
  # @api public
  #
  def self.range(from, to)
    # optimize eq with symbol (faster when it is left)
    from = :default == from if from == 'default'
    to = :default if to == 'default'
    PIntegerType.new(from, to)
  end

  # Produces a Float range type
  # @api public
  #
  def self.float_range(from, to)
    # optimize eq with symbol (faster when it is left)
    from = Float(from) unless :default == from || from.nil?
    to = Float(to) unless :default == to || to.nil?
    PFloatType.new(from, to)
  end

  # Produces the Float type
  # @api public
  #
  def self.float
    PFloatType::DEFAULT
  end

  # Produces the Sensitive type
  # @api public
  #
  def self.sensitive(type = nil)
    PSensitiveType.new(type)
  end

  # Produces the Numeric type
  # @api public
  #
  def self.numeric
    PNumericType::DEFAULT
  end

  # Produces the Init type
  # @api public
  def self.init(*args)
    case args.size
    when 0
      PInitType::DEFAULT
    when 1
      type = args[0]
      type.nil? ? PInitType::DEFAULT : PInitType.new(type, EMPTY_ARRAY)
    else
      type = args.shift
      PInitType.new(type, args)
    end
  end

  # Produces the Iterable type
  # @api public
  #
  def self.iterable(elem_type = nil)
    elem_type.nil? ? PIterableType::DEFAULT : PIterableType.new(elem_type)
  end

  # Produces the Iterator type
  # @api public
  #
  def self.iterator(elem_type = nil)
    elem_type.nil? ? PIteratorType::DEFAULT : PIteratorType.new(elem_type)
  end

  # Produces a string representation of the type
  # @api public
  #
  def self.label(t)
    @type_calculator.string(t)
  end

  # Produces the String type based on nothing, a string value that becomes an exact match constraint, or a parameterized
  # Integer type that constraints the size.
  #
  # @api public
  #
  def self.string(size_type_or_value = nil, *deprecated_second_argument)
    if deprecated_second_argument.empty?
      size_type_or_value.nil? ? PStringType::DEFAULT : PStringType.new(size_type_or_value)
    else
      if Puppet[:strict] != :off
        #TRANSLATORS 'TypeFactory#string' is a class and method name and should not be translated
        message = _("Passing more than one argument to TypeFactory#string is deprecated")
        Puppet.warn_once('deprecations', "TypeFactory#string_multi_args", message)
      end
      deprecated_second_argument.size == 1 ? PStringType.new(deprecated_second_argument[0]) : PEnumType.new(*deprecated_second_argument)
    end
  end

  # Produces the Optional type, i.e. a short hand for Variant[T, Undef]
  # If the given 'optional_type' argument is a String, then it will be
  # converted into a String type that represents that string.
  #
  # @param optional_type [String,PAnyType,nil] the optional type
  # @return [POptionalType] the created type
  #
  # @api public
  #
  def self.optional(optional_type = nil)
    if optional_type.nil?
      POptionalType::DEFAULT
    else
      POptionalType.new(type_of(optional_type.is_a?(String) ? string(optional_type) : type_of(optional_type)))
    end
  end

  # Produces the Enum type, optionally with specific string values
  # @api public
  #
  def self.enum(*values)
    last = values.last
    case_insensitive = false
    if last == true || last == false
      case_insensitive = last
      values = values[0...-1]
    end
    PEnumType.new(values, case_insensitive)
  end

  # Produces the Variant type, optionally with the "one of" types
  # @api public
  #
  def self.variant(*types)
    PVariantType.maybe_create(types.map {|v| type_of(v) })
  end

  # Produces the Struct type, either a non parameterized instance representing
  # all structs (i.e. all hashes) or a hash with entries where the key is
  # either a literal String, an Enum with one entry, or a String representing exactly one value.
  # The key type may also be wrapped in a NotUndef or an Optional.
  #
  # The value can be a ruby class, a String (interpreted as the name of a ruby class) or
  # a Type.
  #
  # @param hash [{String,PAnyType=>PAnyType}] key => value hash
  # @return [PStructType] the created Struct type
  #
  def self.struct(hash = {})
    tc = @type_calculator
    elements = hash.map do |key_type, value_type|
      value_type = type_of(value_type)
      raise ArgumentError, 'Struct element value_type must be a Type' unless value_type.is_a?(PAnyType)

      # TODO: Should have stricter name rule
      if key_type.is_a?(String)
        raise ArgumentError, 'Struct element key cannot be an empty String' if key_type.empty?
        key_type = string(key_type)
        # Must make key optional if the value can be Undef
        key_type = optional(key_type) if tc.assignable?(value_type, PUndefType::DEFAULT)
      else
        # assert that the key type is one of String[1], NotUndef[String[1]] and Optional[String[1]]
        case key_type
        when PNotUndefType
          # We can loose the NotUndef wrapper here since String[1] isn't optional anyway
          key_type = key_type.type
          s = key_type
        when POptionalType
          s = key_type.optional_type
        when PStringType
          s = key_type
        when PEnumType
          s = key_type.values.size == 1 ? PStringType.new(key_type.values[0]) : nil
        else
          raise ArgumentError, "Illegal Struct member key type. Expected NotUndef, Optional, String, or Enum. Got: #{key_type.class.name}"
        end
        unless s.is_a?(PStringType) && !s.value.nil?
          raise ArgumentError, "Unable to extract a non-empty literal string from Struct member key type #{tc.string(key_type)}"
        end
      end
      PStructElement.new(key_type, value_type)
    end
    PStructType.new(elements)
  end

  # Produces an `Object` type from the given _hash_ that represents the features of the object
  #
  # @param hash [{String=>Object}] the hash of feature groups
  # @return [PObjectType] the created type
  #
  def self.object(hash = nil, loader = nil)
    hash.nil? || hash.empty? ? PObjectType::DEFAULT : PObjectType.new(hash, loader)
  end

  def self.type_set(hash = nil)
    hash.nil? || hash.empty? ? PTypeSetType::DEFAULT : PTypeSetType.new(hash)
  end

  def self.timestamp(*args)
    case args.size
    when 0
      PTimestampType::DEFAULT
    else
      PTimestampType.new(*args)
    end
  end

  def self.timespan(*args)
    case args.size
    when 0
      PTimespanType::DEFAULT
    else
      PTimespanType.new(*args)
    end
  end

  def self.tuple(types = [], size_type = nil)
    PTupleType.new(types.map {|elem| type_of(elem) }, size_type)
  end

  # Produces the Boolean type
  # @api public
  #
  def self.boolean(value = nil)
    value.nil? ? PBooleanType::DEFAULT : (value ? PBooleanType::TRUE : PBooleanType::FALSE)
  end

  # Produces the Any type
  # @api public
  #
  def self.any
    PAnyType::DEFAULT
  end

  # Produces the Regexp type
  # @param pattern [Regexp, String, nil] (nil) The regular expression object or
  #   a regexp source string, or nil for bare type
  # @api public
  #
  def self.regexp(pattern = nil)
    pattern ?  PRegexpType.new(pattern) : PRegexpType::DEFAULT
  end

  def self.pattern(*regular_expressions)
    patterns = regular_expressions.map do |re|
      case re
      when String
        re_t = PRegexpType.new(re)
        re_t.regexp  # compile it to catch errors
        re_t

      when Regexp
        PRegexpType.new(re)

      when PRegexpType
        re

      when PPatternType
        re.patterns

     else
       raise ArgumentError, "Only String, Regexp, Pattern-Type, and Regexp-Type are allowed: got '#{re.class}"
      end
    end.flatten.uniq
    PPatternType.new(patterns)
  end

  # Produces the Scalar type
  # @api public
  #
  def self.scalar
    PScalarType::DEFAULT
  end

  # Produces the ScalarData type
  # @api public
  #
  def self.scalar_data
    PScalarDataType::DEFAULT
  end

  # Produces a CallableType matching all callables
  # @api public
  #
  def self.all_callables
    return PCallableType::DEFAULT
  end

  # Produces a Callable type with one signature without support for a block
  # Use #with_block, or #with_optional_block to add a block to the callable
  # If no parameters are given, the Callable will describe a signature
  # that does not accept parameters. To create a Callable that matches all callables
  # use {#all_callables}.
  #
  # The params is a list of types, where the three last entries may be
  # optionally followed by min, max count, and a Callable which is taken as the
  # block_type.
  # If neither min or max are specified the parameters must match exactly.
  # A min < params.size means that the difference are optional.
  # If max > params.size means that the last type repeats.
  # if max is :default, the max value is unbound (infinity).
  #
  # Params are given as a sequence of arguments to {#type_of}.
  #
  def self.callable(*params)
    if params.size == 2 && params[0].is_a?(Array)
      return_t = type_of(params[1])
      params = params[0]
    else
      return_t = nil
    end
    last_callable = TypeCalculator.is_kind_of_callable?(params.last)
    block_t = last_callable ? params.pop : nil

    # compute a size_type for the signature based on the two last parameters
    if is_range_parameter?(params[-2]) && is_range_parameter?(params[-1])
      size_type = range(params[-2], params[-1])
      params = params[0, params.size - 2]
    elsif is_range_parameter?(params[-1])
      size_type = range(params[-1], :default)
      params = params[0, params.size - 1]
    else
      size_type = nil
    end

    types = params.map {|p| type_of(p) }

    # If the specification requires types, and none were given, a Unit type is used
    if types.empty? && !size_type.nil? && size_type.range[1] > 0
      types << PUnitType::DEFAULT
    end
    # create a signature
    tuple_t = tuple(types, size_type)
    PCallableType.new(tuple_t, block_t, return_t)
  end

  # Produces the abstract type Collection
  # @api public
  #
  def self.collection(size_type = nil)
    size_type.nil? ? PCollectionType::DEFAULT : PCollectionType.new(size_type)
  end

  # Produces the Data type
  # @api public
  #
  def self.data
    @data_t ||= TypeParser.singleton.parse('Data', Loaders.static_loader)
  end

  # Produces the RichData type
  # @api public
  #
  def self.rich_data
    @rich_data_t ||= TypeParser.singleton.parse('RichData', Loaders.static_loader)
  end

  # Produces the RichData type
  # @api public
  #
  def self.rich_data_key
    @rich_data_key_t ||= TypeParser.singleton.parse('RichDataKey', Loaders.static_loader)
  end

  # Creates an instance of the Undef type
  # @api public
  def self.undef
    PUndefType::DEFAULT
  end

  # Creates an instance of the Default type
  # @api public
  def self.default
    PDefaultType::DEFAULT
  end

  # Creates an instance of the Binary type
  # @api public
  def self.binary
    PBinaryType::DEFAULT
  end

  # Produces an instance of the abstract type PCatalogEntryType
  def self.catalog_entry
    PCatalogEntryType::DEFAULT
  end

  # Produces an instance of the SemVerRange type
  def self.sem_ver_range
    PSemVerRangeType::DEFAULT
  end

  # Produces an instance of the SemVer type
  def self.sem_ver(*ranges)
    ranges.empty? ? PSemVerType::DEFAULT : PSemVerType::new(ranges)
  end

  # Produces a PResourceType with a String type_name A PResourceType with a nil
  # or empty name is compatible with any other PResourceType.  A PResourceType
  # with a given name is only compatible with a PResourceType with the same
  # name.  (There is no resource-type subtyping in Puppet (yet)).
  #
  def self.resource(type_name = nil, title = nil)
    case type_name
    when PResourceType
      PResourceType.new(type_name.type_name, title)
    when String
      type_name = TypeFormatter.singleton.capitalize_segments(type_name)
      raise ArgumentError, "Illegal type name '#{type_name}'" unless type_name =~ Patterns::CLASSREF_EXT
      PResourceType.new(type_name, title)
    when nil
      raise ArgumentError, 'The type name cannot be nil, if title is given' unless title.nil?
      PResourceType::DEFAULT
    else
      raise ArgumentError, "The type name cannot be a #{type_name.class.name}"
    end
  end

  # Produces PClassType with a string class_name.  A PClassType with
  # nil or empty name is compatible with any other PClassType.  A
  # PClassType with a given name is only compatible with a PClassType
  # with the same name.
  #
  def self.host_class(class_name = nil)
    if class_name.nil?
      PClassType::DEFAULT
    else
      PClassType.new(class_name.sub(/^::/, ''))
    end
  end

  # Produces a type for Array[o] where o is either a type, or an instance for
  # which a type is inferred.
  # @api public
  #
  def self.array_of(o, size_type = nil)
    PArrayType.new(type_of(o), size_type)
  end

  # Produces a type for Hash[Scalar, o] where o is either a type, or an
  # instance for which a type is inferred.
  # @api public
  #
  def self.hash_of(value, key = scalar, size_type = nil)
    PHashType.new(type_of(key), type_of(value), size_type)
  end

  # Produces a type for Hash[key,value,size]
  # @param key_type [PAnyType] the key type
  # @param value_type [PAnyType] the value type
  # @param size_type [PIntegerType]
  # @return [PHashType] the created hash type
  # @api public
  #
  def self.hash_kv(key_type, value_type, size_type = nil)
    PHashType.new(key_type, value_type, size_type)
  end

  # Produces a type for Array[Any]
  # @api public
  #
  def self.array_of_any
    PArrayType::DEFAULT
  end

  # Produces a type for Array[Data]
  # @api public
  #
  def self.array_of_data
    @array_of_data_t = PArrayType.new(data)
  end

  # Produces a type for Hash[Any,Any]
  # @api public
  #
  def self.hash_of_any
    PHashType::DEFAULT
  end

  # Produces a type for Hash[String,Data]
  # @api public
  #
  def self.hash_of_data
    @hash_of_data_t = PHashType.new(string, data)
  end

  # Produces a type for NotUndef[T]
  # The given 'inst_type' can be a string in which case it will be converted into
  # the type String[inst_type].
  #
  # @param inst_type [Type,String] the type to qualify
  # @return [PNotUndefType] the NotUndef type
  #
  # @api public
  #
  def self.not_undef(inst_type = nil)
    inst_type = string(inst_type) if inst_type.is_a?(String)
    PNotUndefType.new(inst_type)
  end

  # Produces a type for Type[T]
  # @api public
  #
  def self.type_type(inst_type = nil)
    inst_type.nil? ? PTypeType::DEFAULT : PTypeType.new(inst_type)
  end

  # Produces a type for Error
  # @api public
  #
  def self.error
    @error_t ||= TypeParser.singleton.parse('Error', Loaders.loaders.puppet_system_loader)
  end

  def self.task
    @task_t ||= TypeParser.singleton.parse('Task')
  end

  # Produces a type for URI[String or Hash]
  # @api public
  #
  def self.uri(string_uri_or_hash = nil)
    string_uri_or_hash.nil? ? PURIType::DEFAULT : PURIType.new(string_uri_or_hash)
  end

  # Produce a type corresponding to the class of given unless given is a
  # String, Class or a PAnyType.  When a String is given this is taken as
  # a classname.
  #
  def self.type_of(o)
    if o.is_a?(Class)
      @type_calculator.type(o)
    elsif o.is_a?(PAnyType)
      o
    elsif o.is_a?(String)
      PRuntimeType.new(:ruby, o)
    else
      @type_calculator.infer_generic(o)
    end
  end

  # Produces a type for a class or infers a type for something that is not a
  # class
  # @note
  #   To get the type for the class' class use `TypeCalculator.infer(c)`
  #
  # @overload ruby(o)
  #   @param o [Class] produces the type corresponding to the class (e.g.
  #     Integer becomes PIntegerType)
  # @overload ruby(o)
  #   @param o [Object] produces the type corresponding to the instance class
  #     (e.g. 3 becomes PIntegerType)
  #
  # @api public
  #
  def self.ruby(o)
    if o.is_a?(Class)
      @type_calculator.type(o)
    else
      PRuntimeType.new(:ruby, o.class.name)
    end
  end

  # Generic creator of a RuntimeType["ruby"] - allows creating the Ruby type
  # with nil name, or String name.  Also see ruby(o) which performs inference,
  # or mapps a Ruby Class to its name.
  #
  def self.ruby_type(class_name = nil)
    PRuntimeType.new(:ruby, class_name)
  end

  # Generic creator of a RuntimeType - allows creating the type with nil or
  # String runtime_type_name.  Also see ruby_type(o) and ruby(o).
  #
  def self.runtime(runtime=nil, runtime_type_name = nil)
    runtime = runtime.to_sym if runtime.is_a?(String)
    PRuntimeType.new(runtime, runtime_type_name)
  end

  # Returns the type alias for the given expression
  # @param name [String] the name of the unresolved type
  # @param expression [Model::Expression] an expression that will evaluate to a type
  # @return [PTypeAliasType] the type alias
  def self.type_alias(name = nil, expression = nil)
    name.nil? ? PTypeAliasType::DEFAULT : PTypeAliasType.new(name, expression)
  end

  # Returns the type that represents a type reference with a given name and optional
  # parameters.
  # @param type_string [String] the string form of the type
  # @return [PTypeReferenceType] the type reference
  def self.type_reference(type_string = nil)
    type_string == nil ? PTypeReferenceType::DEFAULT : PTypeReferenceType.new(type_string)
  end

  # Returns true if the given type t is of valid range parameter type (integer
  # or literal default).
  def self.is_range_parameter?(t)
    t.is_a?(Integer) || t == 'default' || :default == t
  end

end
end
end
