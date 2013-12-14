# Helper module that makes creation of type objects simpler.
# @api public
#
module Puppet::Pops::Types::TypeFactory
  @type_calculator = Puppet::Pops::Types::TypeCalculator.new()

  Types = Puppet::Pops::Types

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
    t = Types::PIntegerType.new()
    t.from = from unless from == :default
    t.to = to unless to == :default
    t
  end

  # Produces a Float range type
  # @api public
  #
  def self.float_range(from, to)
    t = Types::PFloatType.new()
    t.from = Float(from) unless from == :default || from.nil?
    t.to = Float(to) unless to == :default || to.nil?
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

  # Produces the Boolean type
  # @api public
  #
  def self.boolean()
    Types::PBooleanType.new()
  end

  # Produces the Object type
  # @api public
  #
  def self.object()
    Types::PObjectType.new()
  end

  # Produces the Regexp type
  # @param pattern [Regexp, String, nil] (nil) The regular expression object or a regexp source string, or nil for bare type
  # @api public
  #
  def self.regexp(pattern = nil)
    t = Types::PRegexpType.new()
    if pattern
      t.pattern = pattern.is_a?(Regexp) ? pattern.inspect[1..-2] : pattern
    end
    t
  end

  def self.pattern(*regular_expressions)
    t = Types::PPatternType.new()
    regular_expressions.each do |re|
      case re
      when String
        re_T = Types::PRegexpType.new()
        re_T.pattern = re
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
  def self.literal()
    Types::PLiteralType.new()
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
    Types::PNilType.new()
  end

  # Produces an instance of the abstract type PCatalogEntryType
  def self.catalog_entry()
    Types::PCatalogEntryType.new()
  end

  # Produces a PResourceType with a String type_name
  # A PResourceType with a nil or empty name is compatible with any other PResourceType.
  # A PResourceType with a given name is only compatible with a PResourceType with the same name.
  # (There is no resource-type subtyping in Puppet (yet)).
  #
  def self.resource(type_name = nil, title = nil)
    type = Types::PResourceType.new()
    type_name = type_name.type_name if type_name.is_a?(Types::PResourceType)
    type.type_name = type_name.downcase unless type_name.nil?
    type.title = title
    type
  end

  # Produces PHostClassType with a string class_name.
  # A PHostClassType with nil or empty name is compatible with any other PHostClassType.
  # A PHostClassType with a given name is only compatible with a PHostClassType with the same name.
  #
  def self.host_class(class_name = nil)
    type = Types::PHostClassType.new()
    type.class_name = class_name
    type
  end

  # Produces a type for Array[o] where o is either a type, or an instance for which a type is inferred.
  # @api public
  #
  def self.array_of(o)
    type = Types::PArrayType.new()
    type.element_type = type_of(o)
    type
  end

  # Produces a type for Hash[Literal, o] where o is either a type, or an instance for which a type is inferred.
  # @api public
  #
  def self.hash_of(value, key = literal())
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

  # Produces a type for Hash[Literal, Data]
  # @api public
  #
  def self.hash_of_data()
    type = Types::PHashType.new()
    type.key_type = literal()
    type.element_type = data()
    type
  end

  # Produce a type corresponding to the class of given unless given is a String, Class or a PObjectType.
  # When a String is given this is taken as a classname.
  #
  def self.type_of(o)
    if o.is_a?(Class)
      @type_calculator.type(o)
    elsif o.is_a?(Types::PObjectType)
      o
    elsif o.is_a?(String)
      type = Types::PRubyType.new()
      type.ruby_class = o
      type
    else
      @type_calculator.infer_generic(o)
    end
  end

  # Produces a type for a class or infers a type for something that is not a class
  # @note
  #   To get the type for the class' class use `TypeCalculator.infer(c)`
  #
  # @overload ruby(o)
  #   @param o [Class] produces the type corresponding to the class (e.g. Integer becomes PIntegerType)
  # @overload ruby(o)
  #   @param o [Object] produces the type corresponding to the instance class (e.g. 3 becomes PIntegerType)
  #
  # @api public
  #
  def self.ruby(o)
    if o.is_a?(Class)
      @type_calculator.type(o)
    else
      type = Types::PRubyType.new()
      type.ruby_class = o.class.name
      type
    end
  end
end
