# The TypeCalculator can answer questions about puppet types.
#
# Inference
# ---------
# The `infer(o)` method infers a puppet type for literal ruby objects, and for Arrays and Hashes.
# It can easily be extended to also infer the result of Expression objects.
#
# Assignability
# -------------
# The `assignable?(t1, t2)` method answers if t2 conforms to t1. The type t2 may be an instance, in which case
# its type is inferred, or a type.
#
# String
# ------
# Creates a string representation of a type.
#
# @api public
#
class Puppet::Pops::Types::TypeCalculator

  Types = Puppet::Pops::Types

  # @api public
  #
  def initialize
    @@assignable_visitor ||= Puppet::Pops::Visitor.new(nil,"assignable",1,1)
    @@infer_visitor ||= Puppet::Pops::Visitor.new(nil,"infer",0,0)
    @@string_visitor ||= Puppet::Pops::Visitor.new(nil,"string",0,0)

    da = Types::PArrayType.new()
    da.element_type = Types::PDataType.new()
    @data_array = da

    h = Types::PHashType.new()
    h.element_type = Types::PDataType.new()
    h.key_type = Types::PLiteralType.new()
    @data_hash = h

    @data_t = Types::PDataType.new()
    @literal_t = Types::PLiteralType.new()
    @numeric_t = Types::PNumericType.new()
    @t = Types::PObjectType.new()
  end

  # Convenience method to get a data type for comparisons
  # @api private the returned value may not be contained in another element
  #
  def data
    @data_t
  end

  # Answers the question 'is it possible to inject an instance of the given class'
  # A class is injectable if it has a special *assisted inject* class method called `inject` taking
  # an injector and a scope as argument, or if it has a zero args `initialize` method.
  #
  # @param klazz [Class, PRubyType] the class/type to check if it is injectable
  # @return [Class, nil] the injectable Class, or nil if not injectable
  # @api public
  #
  def injectable_class(klazz)
    # Handle case when we get a PType instead of a class
    if klazz.is_a?(Types::PRubyType)
      klazz = Puppet::Pops::Types::ClassLoader.provide(klazz)
    end

    # data types can not be injected (check again, it is not safe to assume that given RubyType klazz arg was ok)
    return false unless type(klazz).is_a?(Types::PRubyType)
    if (klazz.respond_to?(:inject) && klazz.method(:inject).arity() == -4) || klazz.instance_method(:initialize).arity() == 0
      klazz
    else
      nil
    end
  end

  # Answers 'can an instance of type t2 be assigned to a variable of type t'
  # @api public
  #
  def assignable?(t, t2)
    # nil is assignable to anything
    if is_pnil?(t2)
      return true
    end

    if t.is_a?(Class)
      t = type(t)
    end

    if t2.is_a?(Class)
      t2 = type(t2)
    end

    @@assignable_visitor.visit_this(self, t, t2)
 end

  # Answers 'what is the Puppet Type corresponding to the given Ruby class'
 # @param c [Class] the class for which a puppet type is wanted
  # @api public
  #
  def type(c)
    raise ArgumentError, "Argument must be a Class" unless c.is_a? Class

    # Can't use a visitor here since we don't have an instance of the class
    case
    when c <= Integer
      type = Types::PIntegerType.new()
    when c == Float
      type = Types::PFloatType.new()
    when c == Numeric
      type = Types::PNumericType.new()
    when c == String
      type = Types::PStringType.new()
    when c == Regexp
      type = Types::PPatternType.new()
    when c == NilClass
      type = Types::PNilType.new()
    when c == FalseClass, c == TrueClass
      type = Types::PBooleanType.new()
    when c == Class
      type = Types::PType.new()
    when c == Array
      # Assume array of data values
      type = Types::PArrayType.new()
      type.element_type = Types::PDataType.new()
    when c == Hash
      # Assume hash with literal keys and data values
      type = Types::PHashType.new()
      type.key_type = Types::PLiteralType.new()
      type.element_type = Types::PDataType.new()
    else
      type = Types::PRubyType.new()
      type.ruby_class = c.name
    end
    type
  end

  # Answers 'what is the Puppet Type of o'
  # @api public
  #
  def infer(o)
    @@infer_visitor.visit_this(self, o)
  end

  # Answers 'is o an instance of type t'
  # @api public
  #
  def instance?(t, o)
    assignable?(t, infer(o))
  end

  # Answers if t is a puppet type
  # @api public
  #
  def is_ptype?(t)
    return t.is_a?(Types::PObjectType)
  end

  # Answers if t represents the puppet type PNilType
  # @api public
  #
  def is_pnil?(t)
    return t.nil? || t.is_a?(Types::PNilType)
  end

  # Answers, 'What is the common type of t1 and t2?'
  # @api public
  #
  def common_type(t1, t2)
    raise ArgumentError, 'two types expected' unless (is_ptype?(t1) || is_pnil?(t1)) && (is_ptype?(t2) || is_pnil?(t2))

    # if either is nil, the common type is the other
    if is_pnil?(t1)
      return t2
    elsif is_pnil?(t2)
      return t1
    end

    # Simple case, one is assignable to the other
    if assignable?(t1, t2)
      return t1
    elsif assignable?(t2, t1)
      return t2
    end

    # when both are arrays, return an array with common element type
    if t1.is_a?(Types::PArrayType) && t2.is_a?(Types::PArrayType)
      type = Types::PArrayType.new()
      type.element_type = common_type(t1.element_type, t2.element_type)
      return type
    end

    # when both are hashes, return a hash with common key- and element type
    if t1.is_a?(Types::PHashType) && t2.is_a?(Types::PHashType)
      type = Types::PHashType.new()
      type.key_type = common_type(t1.key_type, t2.key_type)
      type.element_type = common_type(t1.element_type, t2.element_type)
      return type
    end

    # Common abstract types, from most specific to most general
    if common_numeric?(t1, t2)
      return Types::PNumericType.new()
    end

    if common_literal?(t1, t2)
      return Types::PLiteralType.new()
    end

    if common_data?(t1,t2)
      return Types::PDataType.new()
    end

    # If both are RubyObjects

    if common_pobject?(t1, t2)
      return Types::PObjectType.new()
    end
  end

  # Produces a string representing the type
  # @api public
  #
  def string(t)
    @@string_visitor.visit_this(self, t)
  end


  # Reduces an enumerable of types to a single common type.
  # @api public
  #
  def reduce_type(enumerable)
    enumerable.reduce(nil) {|memo, t| common_type(memo, t) }
  end

  # Reduce an enumerable of objects to a single common type
  # @api public
  #
  def infer_and_reduce_type(enumerable)
    reduce_type(enumerable.collect() {|o| infer(o) })
  end

  # The type of all classes is PType
  # @api private
  #
  def infer_Class(o)
    Types::PType.new()
  end

  # @api private
  def infer_Object(o)
    type = Types::PRubyType.new()
    type.ruby_class = o.class.name
    type
  end

  # The type of all types is PType
  # @api private
  #
  def infer_PObjectType(o)
    Types::PType.new()
  end

  # The type of all types is PType
  # This is the metatype short circuit.
  # @api private
  #
  def infer_PType(o)
    Types::PType.new()
  end

  # @api private
  def infer_String(o)
    Types::PStringType.new()
  end

  # @api private
  def infer_Float(o)
    Types::PFloatType.new()
  end

  # @api private
  def infer_Integer(o)
    Types::PIntegerType.new()
  end

  # @api private
  def infer_Regexp(o)
    Types::PPatternType.new()
  end

  # @api private
  def infer_NilClass(o)
    Types::PNilType.new()
  end

  # @api private
  def infer_TrueClass(o)
    Types::PBooleanType.new()
  end

  # @api private
  def infer_FalseClass(o)
    Types::PBooleanType.new()
  end

  # @api private
  def infer_Array(o)
    type = Types::PArrayType.new()
    type.element_type = if o.empty?
      Types::PNilType.new()
    else
      infer_and_reduce_type(o)
    end
    type
  end

  # @api private
  def infer_Hash(o)
    type = Types::PHashType.new()
    if o.empty?
      ktype = Types::PNilType.new()
      etype = Types::PNilType.new()
    else
      ktype = infer_and_reduce_type(o.keys())
      etype = infer_and_reduce_type(o.values())
    end
    type.key_type = ktype
    type.element_type = etype
    type
  end

  # False in general type calculator 
  # @api private
  def assignable_Object(t, t2)
    false
  end

  # @api private
  def assignable_PObjectType(t, t2)
    t2.is_a?(Types::PObjectType)
  end

  # @api private
  def assignable_PDataType(t, t2)
    t2.is_a?(Types::PDataType)
  end

  # @api private
  def assignable_PLiteralType(t, t2)
    t2.is_a?(Types::PLiteralType)
  end

  # @api private
  def assignable_PNumericType(t, t2)
    t2.is_a?(Types::PNumericType)
  end

  # @api private
  def assignable_PIntegerType(t, t2)
    t2.is_a?(Types::PIntegerType)
  end

  # @api private
  def assignable_PStringType(t, t2)
    t2.is_a?(Types::PStringType)
  end

  # @api private
  def assignable_PFloatType(t, t2)
    t2.is_a?(Types::PFloatType)
  end

  # @api private
  def assignable_PBooleanType(t, t2)
    t2.is_a?(Types::PBooleanType)
  end

  # @api private
  def assignable_PPatternType(t, t2)
    t2.is_a?(Types::PPatternType)
  end

  # @api private
  def assignable_PCollectionType(t, t2)
    t2.is_a?(Types::PCollectionType)
  end

  # Array is assignable if t2 is an Array and t2's element type is assignable
  # @api private
  def assignable_PArrayType(t, t2)
    return false unless t2.is_a?(Types::PArrayType)
    assignable?(t.element_type, t2.element_type)
  end

  # Hash is assignable if t2 is a Hash and t2's key and element types are assignable
  # @api private
  def assignable_PHashType(t, t2)
    return false unless t2.is_a?(Types::PHashType)
    assignable?(t.key_type, t2.key_type) && assignable?(t.element_type, t2.element_type)
  end

  # Data is assignable by other Data and by Array[Data] and Hash[Literal, Data]
  # @api private
  def assignable_PDataType(t, t2)
    t2.is_a?(Types::PDataType) || assignable?(@data_array, t2) || assignable?(@data_hash, t2)
  end

  # Assignable if t2's ruby class is same or subclass of t1's ruby class
  # @api private
  def assignable_PRubyType(t1, t2)
    return false unless t2.is_a?(Types::PRubyType)
    c1 = class_from_string(t1.ruby_class)
    c2 = class_from_string(t2.ruby_class)
    return false unless c1.is_a?(Class) && c2.is_a?(Class)
    !!(c2 <= c1)
  end

  # @api private
  def string_PType(t)        ; "Type"    ; end

  # @api private
  def string_PObjectType(t)  ; "Object"  ; end

  # @api private
  def string_PLiteralType(t) ; "Literal" ; end

  # @api private
  def string_PDataType(t)    ; "Data"    ; end

  # @api private
  def string_PNumericType(t) ; "Numeric" ; end

  # @api private
  def string_PIntegerType(t) ; "Integer" ; end

  # @api private
  def string_PFloatType(t)   ; "Float"   ; end

  # @api private
  def string_PPatternType(t) ; "Pattern" ; end

  # @api private
  def string_PStringType(t)  ; "String"  ; end

    # @api private
  def string_PRubyType(t)   ; "Ruby[#{t.ruby_class}]"  ; end

  # @api private
  def string_PArrayType(t)
    "Array[#{string(t.element_type)}]"
  end

  # @api private
  def string_PHashType(t)
    "Hash[#{string(t.key_type)}, #{string(t.element_type)}]"
  end

  private

  def class_from_string(str)
    str.split('::').inject(Object) do |memo, name_segment|
      memo.const_get(name_segment)
    end
  end

  def common_data?(t1, t2)
    assignable?(@data_t, t1) && assignable?(@data_t, t2)
  end

  def common_literal?(t1, t2)
    assignable?(@literal_t, t1) && assignable?(@literal_t, t2)
  end

  def common_numeric?(t1, t2)
    assignable?(@numeric_t, t1) && assignable?(@numeric_t, t2)
  end

  def common_pobject?(t1, t2)
    assignable?(@t, t1) && assignable?(@t, t2)
  end
end
