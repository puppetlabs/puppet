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

  # Produces the Float type
  # @api public
  #
  def self.float()
    Types::PFloatType.new()
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
    type.element_type = if o.is_a?(Types::PObjectType)
      o
    else
      @type_calculator.infer(o)
    end
    type
  end

  # Produces a type for Hash[Literal, o] where o is either a type, or an instance for which a type is inferred.
  # @api public
  #
  def self.hash_of(value, key = literal())
    type = Types::PHashType.new()
    type.key_type = key
    type.element_type = if value.is_a?(Types::PObjectType)
      value
    else
      @type_calculator.infer(value)
    end
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

  def self.ruby(o)
    type = Types::PRubyType.new()
    if o.is_a?(Class)
      type.ruby_class = o.name
    else
      type.ruby_class = o.class.name
    end
    type
  end
end