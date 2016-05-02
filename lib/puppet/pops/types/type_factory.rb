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

  # Produces the Numeric type
  # @api public
  #
  def self.numeric
    PNumericType::DEFAULT
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

  # Produces the String type, optionally with specific string values
  # @api public
  #
  def self.string(size_type = nil, *values)
    PStringType.new(size_type, values)
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
    POptionalType.new(type_of(optional_type.is_a?(String) ? string(nil, optional_type) : type_of(optional_type)))
  end

  # Produces the Enum type, optionally with specific string values
  # @api public
  #
  def self.enum(*values)
    PEnumType.new(values)
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
        key_type = string(nil, key_type)
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
        when PStringType, PEnumType
          s = key_type
        else
          raise ArgumentError, "Illegal Struct member key type. Expected NotUndef, Optional, String, or Enum. Got: #{key_type.class.name}"
        end
        unless (s.is_a?(PStringType) || s.is_a?(PEnumType)) && s.values.size == 1 && !s.values[0].empty?
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
  def self.object(hash = nil)
    hash.nil? || hash.empty? ? PObjectType::DEFAULT : PObjectType.new(hash)
  end

  def self.tuple(types = [], size_type = nil)
    PTupleType.new(types.map {|elem| type_of(elem) }, size_type)
  end

  # Produces the Boolean type
  # @api public
  #
  def self.boolean
    PBooleanType::DEFAULT
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
    if pattern
      t = PRegexpType.new(pattern.is_a?(Regexp) ? pattern.inspect[1..-2] : pattern)
      t.regexp unless pattern.nil? # compile pattern to catch errors
      t
    else
      PRegexpType::DEFAULT
    end
  end

  def self.pattern(*regular_expressions)
    patterns = regular_expressions.map do |re|
      case re
      when String
        re_t = PRegexpType.new(re)
        re_t.regexp  # compile it to catch errors
        re_t

      when Regexp
        # Regep.to_s includes options user did not enter and does not escape source
        # to work either as a string or as a // regexp. The inspect method does a better
        # job, but includes the //
        PRegexpType.new(re.inspect[1..-2])

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

  # Produces the Literal type
  # @api public
  #
  def self.scalar
    PScalarType::DEFAULT
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
    PCallableType.new(tuple_t, block_t)
  end

  # Produces the abstract type Collection
  # @api public
  #
  def self.collection(size_type = nil)
    size_type.nil? ? PCollectionType::DEFAULT : PCollectionType.new(nil, size_type)
  end

  # Produces the Data type
  # @api public
  #
  def self.data
    PDataType::DEFAULT
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
    ranges.empty? ? PSemVerType::DEFAULT : PSemVerType::new(*ranges)
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

  # Produces PHostClassType with a string class_name.  A PHostClassType with
  # nil or empty name is compatible with any other PHostClassType.  A
  # PHostClassType with a given name is only compatible with a PHostClassType
  # with the same name.
  #
  def self.host_class(class_name = nil)
    if class_name.nil?
      PHostClassType::DEFAULT
    else
      PHostClassType.new(class_name.sub(/^::/, ''))
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

  # Produces a type for Array[Data]
  # @api public
  #
  def self.array_of_data
    PArrayType::DATA
  end

  # Produces a type for Hash[Scalar, Data]
  # @api public
  #
  def self.hash_of_data
    PHashType::DATA
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
    inst_type = string(nil, inst_type) if inst_type.is_a?(String)
    PNotUndefType.new(inst_type)
  end

  # Produces a type for Type[T]
  # @api public
  #
  def self.type_type(inst_type = nil)
    inst_type.nil? ? PType::DEFAULT : PType.new(inst_type)
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
