# Helper module that makes creation of type objects simpler.
# @api public
#
module Puppet::Pops::Types::TypeFactory
  Types = Puppet::Pops::Types
  @type_calculator = Types::TypeCalculator.singleton
  @undef_t = Types::PUndefType.new

  # Produces the Integer type
  # @api public
  #
  def self.integer()
    Types::PIntegerType.new()
  end

  # Produces an Integer range type
  # @api public
  #
  def self.range(from, to)
    # NOTE! Do not merge the following line to 4.x. It has the same check in the initialize method
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to

    t = Types::PIntegerType.new()
    # optimize eq with symbol (faster when it is left)
    t.from = from unless (:default == from || from == 'default')
    t.to = to unless (:default == to || to == 'default')
    t
  end

  # Produces a Float range type
  # @api public
  #
  def self.float_range(from, to)
    # NOTE! Do not merge the following line to 4.x. It has the same check in the initialize method
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to

    t = Types::PFloatType.new()
    # optimize eq with symbol (faster when it is left)
    t.from = Float(from) unless :default == from || from.nil?
    t.to = Float(to) unless :default == to || to.nil?
    t
  end

  # Produces the Float type
  # @api public
  #
  def self.float()
    Types::PFloatType.new()
  end

  # Produces the Numeric type
  # @api public
  #
  def self.numeric()
    Types::PNumericType.new()
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
  def self.string(*values)
    t = Types::PStringType.new()
    values.each {|v| t.addValues(v) }
    t
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
    t = Types::POptionalType.new
    t.optional_type = optional_type.is_a?(String) ? string(optional_type) : type_of(optional_type)
    t
  end

  # Produces the Enum type, optionally with specific string values
  # @api public
  #
  def self.enum(*values)
    t = Types::PEnumType.new()
    values.each {|v| t.addValues(v) }
    t
  end

  # Produces the Variant type, optionally with the "one of" types
  # @api public
  #
  def self.variant(*types)
    t = Types::PVariantType.new()
    types.each {|v| t.addTypes(type_of(v)) }
    t
  end

  # Produces the Struct type, either a non parameterized instance representing
  # all structs (i.e. all hashes) or a hash with entries where the key is
  # either a literal String, an Enum with one entry, or a String representing exactly one value.
  # The key type may also be wrapped in a NotUndef or an Optional.
  #
  # The value can be a ruby class, a String (interpreted as the name of a ruby class) or
  # a Type.
  #
  # @param hash [Hash<Object, Object>] key => value hash
  # @return [PStructType] the created Struct type
  #
  def self.struct(hash = {})
    tc = @type_calculator
    t = Types::PStructType.new
    t.elements = hash.map do |key_type, value_type|
      value_type = type_of(value_type)
      raise ArgumentError, 'Struct element value_type must be a Type' unless value_type.is_a?(Types::PAnyType)

      # TODO: Should have stricter name rule
      if key_type.is_a?(String)
        raise ArgumentError, 'Struct element key cannot be an empty String' if key_type.empty?
        key_type = string(key_type)
        # Must make key optional if the value can be Undef
        key_type = optional(key_type) if tc.assignable?(value_type, @undef_t)
      else
        # assert that the key type is one of String[1], NotUndef[String[1]] and Optional[String[1]]
        case key_type
        when Types::PNotUndefType
          # We can loose the NotUndef wrapper here since String[1] isn't optional anyway
          key_type = key_type.type
          s = key_type
        when Types::POptionalType
          s = key_type.optional_type
        else
          s = key_type
        end
        unless (s.is_a?(Puppet::Pops::Types::PStringType) || s.is_a?(Puppet::Pops::Types::PEnumType)) && s.values.size == 1 && !s.values[0].empty?
          raise ArgumentError, 'Unable to extract a non-empty literal string from Struct member key type' if key_type.empty?
        end
      end
      elem = Types::PStructElement.new
      elem.key_type = key_type
      elem.value_type = value_type
      elem
    end
    t
  end

  def self.tuple(*types)
    t = Types::PTupleType.new
    types.each {|elem| t.addTypes(type_of(elem)) }
    t
  end

  # Produces the Boolean type
  # @api public
  #
  def self.boolean()
    Types::PBooleanType.new()
  end

  # Produces the Any type
  # @api public
  #
  def self.any()
    Types::PAnyType.new()
  end

  # Produces the Regexp type
  # @param pattern [Regexp, String, nil] (nil) The regular expression object or
  #   a regexp source string, or nil for bare type
  # @api public
  #
  def self.regexp(pattern = nil)
    t = Types::PRegexpType.new()
    if pattern
      t.pattern = pattern.is_a?(Regexp) ? pattern.inspect[1..-2] : pattern
    end
    t.regexp() unless pattern.nil? # compile pattern to catch errors
    t
  end

  def self.pattern(*regular_expressions)
    t = Types::PPatternType.new()
    regular_expressions.each do |re|
      case re
      when String
        re_T = Types::PRegexpType.new()
        re_T.pattern = re
        re_T.regexp()  # compile it to catch errors
        t.addPatterns(re_T)

      when Regexp
        re_T = Types::PRegexpType.new()
        # Regep.to_s includes options user did not enter and does not escape source
        # to work either as a string or as a // regexp. The inspect method does a better
        # job, but includes the //
        re_T.pattern = re.inspect[1..-2]
        t.addPatterns(re_T)

      when Types::PRegexpType
        t.addPatterns(re.copy)

      when Types::PPatternType
        re.patterns.each do |p|
          t.addPatterns(p.copy)
        end

     else
       raise ArgumentError, "Only String, Regexp, Pattern-Type, and Regexp-Type are allowed: got '#{re.class}"
      end
    end
    t
  end

  # Produces the Literal type
  # @api public
  #
  def self.scalar()
    Types::PScalarType.new()
  end

  # Produces a CallableType matching all callables
  # @api public
  #
  def self.all_callables()
    return Puppet::Pops::Types::PCallableType.new
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
    if Puppet::Pops::Types::TypeCalculator.is_kind_of_callable?(params.last)
      last_callable = true
    end
    block_t = last_callable ? params.pop : nil

    # compute a size_type for the signature based on the two last parameters
    if is_range_parameter?(params[-2]) && is_range_parameter?(params[-1])
      size_type = range(params[-2], params[-1])
      params = params[0, params.size - 2]
    elsif is_range_parameter?(params[-1])
      size_type = range(params[-1], :default)
      params = params[0, params.size - 1]
    end

    types = params.map {|p| type_of(p) }

    # If the specification requires types, and none were given, a Unit type is used
    if types.empty? && !size_type.nil? && size_type.range[1] > 0
      types << Types::PUnitType.new
    end
    # create a signature
    callable_t = Types::PCallableType.new()
    tuple_t = tuple(*types)
    tuple_t.size_type = size_type unless size_type.nil?
    callable_t.param_types = tuple_t

    callable_t.block_type = block_t
    callable_t
  end

  def self.with_block(callable, *block_params)
    callable.block_type = callable(*block_params)
    callable
  end

  def self.with_optional_block(callable, *block_params)
    callable.block_type = optional(callable(*block_params))
    callable
  end

  # Produces the abstract type Collection
  # @api public
  #
  def self.collection()
    Types::PCollectionType.new()
  end

  # Produces the Data type
  # @api public
  #
  def self.data()
    Types::PDataType.new()
  end

  # Creates an instance of the Undef type
  # @api public
  def self.undef()
    Types::PUndefType.new()
  end

  # Creates an instance of the Default type
  # @api public
  def self.default()
    Types::PDefaultType.new()
  end

  # Produces an instance of the abstract type PCatalogEntryType
  def self.catalog_entry()
    Types::PCatalogEntryType.new()
  end

  # Produces a PResourceType with a String type_name A PResourceType with a nil
  # or empty name is compatible with any other PResourceType.  A PResourceType
  # with a given name is only compatible with a PResourceType with the same
  # name.  (There is no resource-type subtyping in Puppet (yet)).
  #
  def self.resource(type_name = nil, title = nil)
    type = Types::PResourceType.new()
    type_name = type_name.type_name if type_name.is_a?(Types::PResourceType)
    type_name = type_name.downcase unless type_name.nil?
    type.type_name = type_name
    unless type_name.nil? || type_name =~ Puppet::Pops::Patterns::CLASSREF
      raise ArgumentError, "Illegal type name '#{type.type_name}'"
    end
    if type_name.nil? && !title.nil?
      raise ArgumentError, "The type name cannot be nil, if title is given"
    end
    type.title = title
    type
  end

  # Produces PHostClassType with a string class_name.  A PHostClassType with
  # nil or empty name is compatible with any other PHostClassType.  A
  # PHostClassType with a given name is only compatible with a PHostClassType
  # with the same name.
  #
  def self.host_class(class_name = nil)
    type = Types::PHostClassType.new()
    unless class_name.nil?
      type.class_name = class_name.sub(/^::/, '')
    end
    type
  end

  # Produces a type for Array[o] where o is either a type, or an instance for
  # which a type is inferred.
  # @api public
  #
  def self.array_of(o)
    type = Types::PArrayType.new()
    type.element_type = type_of(o)
    type
  end

  # Produces a type for Hash[Scalar, o] where o is either a type, or an
  # instance for which a type is inferred.
  # @api public
  #
  def self.hash_of(value, key = scalar())
    type = Types::PHashType.new()
    type.key_type = type_of(key)
    type.element_type = type_of(value)
    type
  end

  # Produces a type for Array[Data]
  # @api public
  #
  def self.array_of_data()
    type = Types::PArrayType.new()
    type.element_type = data()
    type
  end

  # Produces a type for Hash[Scalar, Data]
  # @api public
  #
  def self.hash_of_data()
    type = Types::PHashType.new()
    type.key_type = scalar()
    type.element_type = data()
    type
  end

  # Produces a type for NotUndef[T]
  # The given 'inst_type' can be a string in which case it will be converted into
  # the type String[inst_type].
  #
  # @param inst_type [Type,String] the type to qualify
  # @return [Puppet::Pops::Types::PNotUndefType] the NotUndef type
  #
  # @api public
  #
  def self.not_undef(inst_type = nil)
    type = Types::PNotUndefType.new()
    inst_type = string(inst_type) if inst_type.is_a?(String)
    type.type = inst_type
    type
  end

  # Produces a type for Type[T]
  # @api public
  #
  def self.type_type(inst_type = nil)
    type = Types::PType.new()
    type.type = inst_type
    type
  end

  # Produce a type corresponding to the class of given unless given is a
  # String, Class or a PAnyType.  When a String is given this is taken as
  # a classname.
  #
  def self.type_of(o)
    if o.is_a?(Class)
      @type_calculator.type(o)
    elsif o.is_a?(Types::PAnyType)
      o
    elsif o.is_a?(String)
      Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => o)
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
      Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => o.class.name)
    end
  end

  # Generic creator of a RuntimeType["ruby"] - allows creating the Ruby type
  # with nil name, or String name.  Also see ruby(o) which performs inference,
  # or mapps a Ruby Class to its name.
  #
  def self.ruby_type(class_name = nil)
    Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => class_name)
  end

  # Generic creator of a RuntimeType - allows creating the type with nil or
  # String runtime_type_name.  Also see ruby_type(o) and ruby(o).
  #
  def self.runtime(runtime=nil, runtime_type_name = nil)
    runtime = runtime.to_sym if runtime.is_a?(String)
    Types::PRuntimeType.new(:runtime => runtime, :runtime_type_name => runtime_type_name)
  end

  # Sets the accepted size range of a collection if something other than the
  # default 0 to Infinity is wanted. The semantics for from/to are the same as
  # for #range
  #
  def self.constrain_size(collection_t, from, to)
    collection_t.size_type = range(from, to)
    collection_t
  end

  # Returns true if the given type t is of valid range parameter type (integer
  # or literal default).
  def self.is_range_parameter?(t)
    t.is_a?(Integer) || t == 'default' || :default == t
  end

end
