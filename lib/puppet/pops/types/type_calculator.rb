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
class Puppet::Pops::Types::TypeCalculator

  # @api public
  #
  def initialize
    @@assignable_visitor ||= Puppet::Pops::Visitor.new(nil,"assignable",1,1)
    @@infer_visitor ||= Puppet::Pops::Visitor.new(nil,"infer",0,0)
    @@string_visitor ||= Puppet::Pops::Visitor.new(nil,"string",0,0)

    da = Puppet::Pops::Types::PArrayType.new()
    da.element_type = Puppet::Pops::Types::PDataType.new()
    @data_array = da

    h = Puppet::Pops::Types::PHashType.new()
    h.element_type = Puppet::Pops::Types::PDataType.new()
    h.key_type = Puppet::Pops::Types::PLiteralType.new()
    @data_hash = h

    @data_t = Puppet::Pops::Types::PDataType.new()
    @literal_t = Puppet::Pops::Types::PLiteralType.new()
    @numeric_t = Puppet::Pops::Types::PNumericType.new()
    @t = Puppet::Pops::Types::PObjectType.new()
  end

  # Answers 'can a t2 be assigned to a t'
  # @api public
  #
  def assignable?(t, t2)
    # nil is assignable to anything
    if is_pnil?(t2)
      return true
    end

    # type compatibility or compatibility of instance's type
    if is_ptype?(t2)
      @@assignable_visitor.visit_this(self, t, t2)
    else
      @@assignable_visitor.visit_this(self, t, infer(t2))
    end
  end

  # Answers 'what is the Puppet Type of o'
  # @api public
  #
  def infer(o)
    @@infer_visitor.visit_this(self, o)
  end

  # Answers if t is a puppet type
  # @api public
  #
  def is_ptype?(t)
    return t.is_a?(Puppet::Pops::Types::PObjectType)
  end

  # Answers if t represents the puppet type PNilType
  # @api public
  #
  def is_pnil?(t)
    return t.nil? || t.is_a?(Puppet::Pops::Types::PNilType)
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

    # Common abstract types, from most specific to most general
    if common_numeric?(t1, t2)
      return Puppet::Pops::Types::PNumericType.new()
    end

    if common_literal?(t1, t2)
      return Puppet::Pops::Types::PLiteralType.new()
    end

    if common_data?(t1,t2)
      return Puppet::Pops::Types::PDataType.new()
    end

    # If both are RubyObjects

    if common_pobject?(t1, t2)
      return Puppet::Pops::Types::PObjectType.new()
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

  # @api private
  def infer_Object(o)
    type = Puppet::Pops::Types::PRubyType.new()
    type.ruby_class = o.class
  end

  # The type of all types is PType
  # This is the metatype short circuit.
  # @api private
  #
  def infer_PType(o)
    Puppet::Pops::Types::PType.new()
  end

  # @api private
  def infer_String(o)
    Puppet::Pops::Types::PStringType.new()
  end

  # @api private
  def infer_Float(o)
    Puppet::Pops::Types::PFloatType.new()
  end

  # @api private
  def infer_Fixnum(o)
    Puppet::Pops::Types::PIntegerType.new()
  end

  # @api private
  def infer_Regexp(o)
    Puppet::Pops::Types::PPatternType.new()
  end

  # @api private
  def infer_TrueClass(o)
    Puppet::Pops::Types::PBooleanType.new()
  end

  # @api private
  def infer_FalseClass(o)
    Puppet::Pops::Types::PBooleanType.new()
  end

  # @api private
  def infer_Array(o)
    type = Puppet::Pops::Types::PArrayType.new()
    type.element_type = if o.empty?
      Puppet::Pops::Types::PNilType.new()
    else
      infer_and_reduce_type(o)
    end
    type
  end

  # @api private
  def infer_Hash(o)
    type = Puppet::Pops::Types::PHashType.new()
    if o.empty?
      ktype = Puppet::Pops::Types::PNilType.new()
      etype = Puppet::Pops::Types::PNilType.new()
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
    t2.is_a?(Puppet::Pops::Types::PObjectType)
  end

  # @api private
  def assignable_PLiteralType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PLiteralType)
  end

  # @api private
  def assignable_PNumericType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PNumericType)
  end

  # @api private
  def assignable_PIntegerType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PIntegerType)
  end

  # @api private
  def assignable_PStringType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PStringType)
  end

  # @api private
  def assignable_PFloatType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PFloatType)
  end

  # @api private
  def assignable_PBooleanType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PBooleanType)
  end

  # @api private
  def assignable_PPatternType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PPatternType)
  end

  # Array is assignable if t2 is an Array and t2's element type is assignable
  # @api private
  def assignable_PArrayType(t, t2)
    return false unless t2.is_a?(Puppet::Pops::Types::PArrayType)
    assignable?(t.element_type, t2.element_type)
  end

  # Hash is assignable if t2 is a Hash and t2's key and element types are assignable
  # @api private
  def assignable_PHashType(t, t2)
    return false unless t2.is_a?(Puppet::Pops::Types::PHashType)
    assignable?(t.key_type, t2.key_type) && assignable?(t.element_type, t2.element_type)
  end

  # Data is assignable by other Data and by Array[Data] and Hash[Literal, Data]
  # @api private
  def assignable_PDataType(t, t2)
    t2.is_a?(Puppet::Pops::Types::PDataType) || assignable?(@data_array, t2) || assignable?(@data_hash, t2)
  end

  # Assignable if t2's ruby class is same or subclass of t1's ruby class
  # @api private
  def assignable_PRubyType(t1, t2)
    return false unless t2.is_a?(Puppet::Pops::Types::PRubyType)
    c1 = class_from_string(t1.ruby_class)
    c2 = class_from_string(t2.ruby_class)
    return false unless c1.is_a?(Class) && c2.is_a?(Class)
    !!(c2 < c1)
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
