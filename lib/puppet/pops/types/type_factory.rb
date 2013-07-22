# Helper module that makes creation of type objects simpler.
# @api public
#
module Puppet::Pops::Types::TypeFactory
  @type_calculator = Puppet::Pops::Types::TypeCalculator.new()

  Types = Puppet::Pops::Types

  # Produces the Object type
  # @api public
  #
  def self.object()
    Types::PObjectType.new()
  end

  # Produces the Integer type
  # @api public
  #
  def self.integer()
    Types::PIntegerType.new()
  end

  # Produces the Float type
  # @api public
  #
  def self.float()
    Types::PFloatType.new()
  end

  # Produces a string representation of the type
  # @api public
  #
  def self.label(t)
    @type_calculator.string(t)
  end

  # Produces the String type
  # @api public
  #
  def self.string()
    Types::PStringType.new()
  end

  # Produces the Boolean type
  # @api public
  #
  def self.boolean()
    Types::PBooleanType.new()
  end

  # Produces the Pattern type
  # @api public
  #
  def self.pattern()
    Types::PPatternType.new()
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
      @type_calculator.infer(o)
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
