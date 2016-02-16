# The TypeCalculator can answer questions about puppet types.
#
# The Puppet type system is primarily based on sub-classing. When asking the type calculator to infer types from Ruby in general, it
# may not provide the wanted answer; it does not for instance take module inclusions and extensions into account. In general the type
# system should be unsurprising for anyone being exposed to the notion of type. The type `Data` may require a bit more explanation; this
# is an abstract type that includes all scalar types, as well as Array with an element type compatible with Data, and Hash with key
# compatible with scalar and elements compatible with Data. Expressed differently; Data is what you typically express using JSON (with
# the exception that the Puppet type system also includes Pattern (regular expression) as a scalar.
#
# Inference
# ---------
# The `infer(o)` method infers a Puppet type for scalar Ruby objects, and for Arrays and Hashes.
# The inference result is instance specific for single typed collections
# and allows answering questions about its embedded type. It does not however preserve multiple types in
# a collection, and can thus not answer questions like `[1,a].infer() =~ Array[Integer, String]` since the inference
# computes the common type Scalar when combining Integer and String.
#
# The `infer_generic(o)` method infers a generic Puppet type for scalar Ruby object, Arrays and Hashes.
# This inference result does not contain instance specific information; e.g. Array[Integer] where the integer
# range is the generic default. Just `infer` it also combines types into a common type.
#
# The `infer_set(o)` method works like `infer` but preserves all type information. It does not do any
# reduction into common types or ranges. This method of inference is best suited for answering questions
# about an object being an instance of a type. It correctly answers: `[1,a].infer_set() =~ Array[Integer, String]`
#
# The `generalize!(t)` method modifies an instance specific inference result to a generic. The method mutates
# the given argument. Basically, this removes string instances from String, and range from Integer and Float.
#
# Assignability
# -------------
# The `assignable?(t1, t2)` method answers if t2 conforms to t1. The type t2 may be an instance, in which case
# its type is inferred, or a type.
#
# Instance?
# ---------
# The `instance?(t, o)` method answers if the given object (instance) is an instance that is assignable to the given type.
#
# String
# ------
# Creates a string representation of a type.
#
# Creation of Type instances
# --------------------------
# Instance of the classes in the {Puppet::Pops::Types type model} are used to denote a specific type. It is most convenient
# to use the {Puppet::Pops::Types::TypeFactory TypeFactory} when creating instances.
#
# @note
#   In general, new instances of the wanted type should be created as they are assigned to models using containment, and a
#   contained object can only be in one container at a time. Also, the type system may include more details in each type
#   instance, such as if it may be nil, be empty, contain a certain count etc. Or put differently, the puppet types are not
#   singletons.
#
# All types support `copy` which should be used when assigning a type where it is unknown if it is bound or not
# to a parent type. A check can be made with `t.eContainer().nil?`
#
# Equality and Hash
# -----------------
# Type instances are equal in terms of Ruby eql? and `==` if they describe the same type, but they are not `equal?` if they are not
# the same type instance. Two types that describe the same type have identical hash - this makes them usable as hash keys.
#
# Types and Subclasses
# --------------------
# In general, the type calculator should be used to answer questions if a type is a subtype of another (using {#assignable?}, or
# {#instance?} if the question is if a given object is an instance of a given type (or is a subtype thereof).
# Many of the types also have a Ruby subtype relationship; e.g. PHashType and PArrayType are both subtypes of PCollectionType, and
# PIntegerType, PFloatType, PStringType,... are subtypes of PScalarType. Even if it is possible to answer certain questions about
# type by looking at the Ruby class of the types this is considered an implementation detail, and such checks should in general
# be performed by the type_calculator which implements the type system semantics.
#
# The PRuntimeType
# -------------
# The PRuntimeType corresponds to a type in the runtime system (currently only supported runtime is 'ruby'). The
# type has a runtime_type_name that corresponds to a Ruby Class name.
# A Runtime[ruby] type can be used to describe any ruby class except for the puppet types that are specialized
# (i.e. PRuntimeType should not be used for Integer, String, etc. since there are specialized types for those).
# When the type calculator deals with PRuntimeTypes and checks for assignability, it determines the
# "common ancestor class" of two classes.
# This check is made based on the superclasses of the two classes being compared. In order to perform this, the
# classes must be present (i.e. they are resolved from the string form in the PRuntimeType to a
# loaded, instantiated Ruby Class). In general this is not a problem, since the question to produce the common
# super type for two objects means that the classes must be present or there would have been
# no instances present in the first place. If however the classes are not present, the type
# calculator will fall back and state that the two types at least have Any in common.
#
# @see Puppet::Pops::Types::TypeFactory TypeFactory for how to create instances of types
# @see Puppet::Pops::Types::TypeParser TypeParser how to construct a type instance from a String
# @see Puppet::Pops::Types Types for details about the type model
#
# Using the Type Calculator
# -----
# The type calculator can be directly used via its class methods. If doing time critical work and doing many
# calls to the type calculator, it is more performant to create an instance and invoke the corresponding
# instance methods. Note that inference is an expensive operation, rather than inferring the same thing
# several times, it is in general better to infer once and then copy the result if mutation to a more generic form is
# required.
#
# @api public
#
class Puppet::Pops::Types::TypeCalculator

  Types = Puppet::Pops::Types
  TheInfinity = 1.0 / 0.0 # because the Infinity symbol is not defined

  # @api public
  def self.assignable?(t1, t2)
    singleton.assignable?(t1,t2)
  end

  # Answers, does the given callable accept the arguments given in args (an array or a tuple)
  # @param callable [Puppet::Pops::Types::PCallableType] - the callable
  # @param args [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] args optionally including a lambda callable at the end
  # @return [Boolan] true if the callable accepts the arguments
  #
  # @api public
  def self.callable?(callable, args)
    singleton.callable?(callable, args)
  end

  # Produces a String representation of the given type.
  # @param t [Puppet::Pops::Types::PAnyType] the type to produce a string form
  # @return [String] the type in string form
  #
  # @api public
  #
  def self.string(t)
    singleton.string(t)
  end

  # @api public
  def self.infer(o)
    singleton.infer(o)
  end

  # @api public
  def self.generalize!(o)
    singleton.generalize!(o)
  end

  # @api public
  def self.infer_set(o)
    singleton.infer_set(o)
  end

  # @api public
  def self.debug_string(t)
    singleton.debug_string(t)
  end

  # @api public
  def self.enumerable(t)
    singleton.enumerable(t)
  end

  # @api private
  def self.singleton()
    @tc_instance ||= new
  end

  # @api public
  #
  def initialize
    @@assignable_visitor ||= Puppet::Pops::Visitor.new(nil,"assignable",1,1)
    @@infer_visitor ||= Puppet::Pops::Visitor.new(nil,"infer",0,0)
    @@infer_set_visitor ||= Puppet::Pops::Visitor.new(nil,"infer_set",0,0)
    @@instance_of_visitor ||= Puppet::Pops::Visitor.new(nil,"instance_of",1,1)
    @@string_visitor ||= Puppet::Pops::Visitor.new(nil,"string",0,0)
    @@inspect_visitor ||= Puppet::Pops::Visitor.new(nil,"debug_string",0,0)
    @@enumerable_visitor ||= Puppet::Pops::Visitor.new(nil,"enumerable",0,0)
    @@extract_visitor ||= Puppet::Pops::Visitor.new(nil,"extract",0,0)
    @@generalize_visitor ||= Puppet::Pops::Visitor.new(nil,"generalize",0,0)
    @@callable_visitor ||= Puppet::Pops::Visitor.new(nil,"callable",1,1)

    da = Types::PArrayType.new()
    da.element_type = Types::PDataType.new()
    @data_array = da

    h = Types::PHashType.new()
    h.element_type = Types::PDataType.new()
    h.key_type = Types::PScalarType.new()
    @data_hash = h

    @data_t = Types::PDataType.new()
    @scalar_t = Types::PScalarType.new()
    @numeric_t = Types::PNumericType.new()
    @t = Types::PAnyType.new()

    # Data accepts a Tuple that has 0-infinity Data compatible entries (e.g. a Tuple equivalent to Array).
    data_tuple = Types::PTupleType.new()
    data_tuple.addTypes(Types::PDataType.new())
    data_tuple.size_type = Types::PIntegerType.new()
    data_tuple.size_type.from = 0
    data_tuple.size_type.to = nil # infinity
    @data_tuple_t = data_tuple

    # Variant type compatible with Data
    data_variant = Types::PVariantType.new()
    data_variant.addTypes(@data_hash.copy)
    data_variant.addTypes(@data_array.copy)
    data_variant.addTypes(Types::PScalarType.new)
    data_variant.addTypes(Types::PUndefType.new)
    data_variant.addTypes(@data_tuple_t.copy)
    @data_variant_t = data_variant

    collection_default_size = Types::PIntegerType.new()
    collection_default_size.from = 0
    collection_default_size.to = nil # infinity
    @collection_default_size_t = collection_default_size

    non_empty_string = Types::PStringType.new
    non_empty_string.size_type = Types::PIntegerType.new()
    non_empty_string.size_type.from = 1
    non_empty_string.size_type.to = nil # infinity
    @non_empty_string_t = non_empty_string

    @nil_t = Types::PUndefType.new
  end

  # Convenience method to get a data type for comparisons
  # @api private the returned value may not be contained in another element
  #
  def data
    @data_t
  end

  # Convenience method to get a variant compatible with the Data type.
  # @api private the returned value may not be contained in another element
  #
  def data_variant
    @data_variant_t
  end

  def self.data_variant
    singleton.data_variant
  end

  # Answers the question 'is it possible to inject an instance of the given class'
  # A class is injectable if it has a special *assisted inject* class method called `inject` taking
  # an injector and a scope as argument, or if it has a zero args `initialize` method.
  #
  # @param klazz [Class, PRuntimeType] the class/type to check if it is injectable
  # @return [Class, nil] the injectable Class, or nil if not injectable
  # @api public
  #
  def injectable_class(klazz)
    # Handle case when we get a PType instead of a class
    if klazz.is_a?(Types::PRuntimeType)
      klazz = Puppet::Pops::Types::ClassLoader.provide(klazz)
    end

    # data types can not be injected (check again, it is not safe to assume that given RubyRuntime klazz arg was ok)
    return false unless type(klazz).is_a?(Types::PRuntimeType)
    if (klazz.respond_to?(:inject) && klazz.method(:inject).arity() == -4) || klazz.instance_method(:initialize).arity() == 0
      klazz
    else
      nil
    end
  end

  # Answers 'can an instance of type t2 be assigned to a variable of type t'.
  # Does not accept nil/undef unless the type accepts it.
  #
  # @api public
  #
  def assignable?(t, t2)
    if t.is_a?(Class)
      t = type(t)
    end

    if t2.is_a?(Class)
      t2 = type(t2)
    end
    t2_class = t2.class

    # Unit can be assigned to anything
    return true if t2_class == Types::PUnitType

    if t2_class == Types::PVariantType
      # Assignable if all contained types are assignable
      t2.types.all? { |vt| @@assignable_visitor.visit_this_1(self, t, vt) }
    else
      # Turn NotUndef[T] into T when T is not assignable from Undef
      if t2_class == Types::PNotUndefType && !(t2.type.nil? || assignable?(t2.type, @nil_t))
        assignable?(t, t2.type)
      else
        @@assignable_visitor.visit_this_1(self, t, t2)
      end
    end
 end

  # Returns an enumerable if the t represents something that can be iterated
  def enumerable(t)
    @@enumerable_visitor.visit_this_0(self, t)
  end

  # Answers, does the given callable accept the arguments given in args (an array or a tuple)
  #
  def callable?(callable, args)
    return false if !self.class.is_kind_of_callable?(callable)
    # Note that polymorphism is for the args type, the callable is always a callable
    @@callable_visitor.visit_this_1(self, args, callable)
  end

  # Answers if the two given types describe the same type
  def equals(left, right)
    return false unless left.is_a?(Types::PAnyType) && right.is_a?(Types::PAnyType)
    # Types compare per class only - an extra test must be made if the are mutually assignable
    # to find all types that represent the same type of instance
    #
    left == right || (assignable?(right, left) && assignable?(left, right))
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
      type = Types::PRegexpType.new()
    when c == NilClass
      type = Types::PUndefType.new()
    when c == FalseClass, c == TrueClass
      type = Types::PBooleanType.new()
    when c == Class
      type = Types::PType.new()
    when c == Array
      # Assume array of data values
      type = Types::PArrayType.new()
      type.element_type = Types::PDataType.new()
    when c == Hash
      # Assume hash with scalar keys and data values
      type = Types::PHashType.new()
      type.key_type = Types::PScalarType.new()
      type.element_type = Types::PDataType.new()
    else
      type = Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => c.name)
    end
    type
  end

  # Generalizes value specific types. The given type is mutated and returned.
  # @api public
  def generalize!(o)
    @@generalize_visitor.visit_this_0(self, o)
    o.eAllContents.each { |x| @@generalize_visitor.visit_this_0(self, x) }
    o
  end

  def generalize_Object(o)
    # do nothing, there is nothing to change for most types
  end

  # @return [Boolean] true if the given argument is contained in a struct element key
  def is_struct_element_key?(o)
    c = o.eContainer
    if c.is_a?(Types::POptionalType)
      o = c
      c = c.eContainer
    end
    c.is_a?(Types::PStructElement) && c.key_type.equal?(o)
  end
  private :is_struct_element_key?

  def generalize_PStringType(o)
    # Skip generalization if the string is contained in a PStructElement key.
    unless is_struct_element_key?(o)
      o.values = []
      o.size_type = nil
    end
  end

  def generalize_PCollectionType(o)
    # erase the size constraint from Array and Hash (if one exists, it is transformed to -Infinity - + Infinity, which is
    # not desirable.
    o.size_type = nil
  end

  def generalize_PFloatType(o)
    o.to = nil
    o.from = nil
  end

  def generalize_PIntegerType(o)
    o.to = nil
    o.from = nil
  end

  # Answers 'what is the single common Puppet Type describing o', or if o is an Array or Hash, what is the
  # single common type of the elements (or keys and elements for a Hash).
  # @api public
  #
  def infer(o)
    @@infer_visitor.visit_this_0(self, o)
  end

  def infer_generic(o)
    result = generalize!(infer(o))
    result
  end

  # Answers 'what is the set of Puppet Types of o'
  # @api public
  #
  def infer_set(o)
    @@infer_set_visitor.visit_this_0(self, o)
  end

  def instance_of(t, o)
    @@instance_of_visitor.visit_this_1(self, t, o)
  end

  def instance_of_Object(t, o)
    # Undef is Undef and Any, but nothing else when checking instance?
    return false if (o.nil?) && t.class != Types::PAnyType
    assignable?(t, infer(o))
  end

  # Anything is an instance of Unit
  # @api private
  def instance_of_PUnitType(t, o)
    true
  end

  def instance_of_PArrayType(t, o)
    return false unless o.is_a?(Array)
    return false unless o.all? {|element| instance_of(t.element_type, element) }
    size_t = t.size_type || @collection_default_size_t
    # optimize by calling directly
    return instance_of_PIntegerType(size_t, o.size)
  end

  # @api private
  def instance_of_PIntegerType(t, o)
    return false unless o.is_a?(Integer)
    x = t.from
    x = -Float::INFINITY if x.nil? || x == :default
    y = t.to
    y = Float::INFINITY if y.nil? || y == :default
    return x < y ? x <= o && y >= o : y <= o && x >= o
  end

  # @api private
  def instance_of_PStringType(t, o)
    return false unless o.is_a?(String)
    # true if size compliant
    size_t = t.size_type
    if size_t.nil? || instance_of_PIntegerType(size_t, o.size)
      values = t.values
      values.empty? || values.include?(o)
    else
      false
    end
  end

  def instance_of_PTupleType(t, o)
    return false unless o.is_a?(Array)
    # compute the tuple's min/max size, and check if that size matches
    size_t = t.size_type || Puppet::Pops::Types::TypeFactory.range(*t.size_range)

    return false unless instance_of_PIntegerType(size_t, o.size)
    o.each_with_index do |element, index|
       return false unless instance_of(t.types[index] || t.types[-1], element)
    end
    true
  end

  def instance_of_PStructType(t, o)
    return false unless o.is_a?(Hash)
    matched = 0
    t.elements.all? do |e|
      key = e.name
      v = o[key]
      if v.nil? && !o.include?(key)
        # Entry is missing. Only OK when key is optional
        assignable?(e.key_type, @nil_t)
      else
        matched += 1
        instance_of(e.value_type, v)
      end
    end && matched == o.size
  end

  def instance_of_PHashType(t, o)
    return false unless o.is_a?(Hash)
    key_t = t.key_type
    element_t = t.element_type
    return false unless o.keys.all? {|key| instance_of(key_t, key) } && o.values.all? {|value| instance_of(element_t, value) }
    size_t = t.size_type || @collection_default_size_t
    # optimize by calling directly
    return instance_of_PIntegerType(size_t, o.size)
  end

  def instance_of_PDataType(t, o)
    instance_of(@data_variant_t, o)
  end

  def instance_of_PNotUndefType(t, o)
    !(o.nil? || o == :undef) && (t.type.nil? || instance_of(t.type, o))
  end

  def instance_of_PUndefType(t, o)
    o.nil? || o == :undef
  end

  def instance_of_POptionalType(t, o)
    instance_of_PUndefType(t, o) || instance_of(t.optional_type, o)
  end

  def instance_of_PVariantType(t, o)
    # instance of variant if o is instance? of any of variant's types
    t.types.any? { |option_t| instance_of(option_t, o) }
  end

  # Answers 'is o an instance of type t'
  # @api public
  #
  def self.instance?(t, o)
    singleton.instance_of(t,o)
  end

  # Answers 'is o an instance of type t'
  # @api public
  #
  def instance?(t, o)
    instance_of(t,o)
  end

  # Answers if t is a puppet type
  # @api public
  #
  def is_ptype?(t)
    return t.is_a?(Types::PAnyType)
  end

  # Answers if t represents the puppet type PUndefType
  # @api public
  #
  def is_pnil?(t)
    return t.nil? || t.is_a?(Types::PUndefType)
  end

  # Answers, 'What is the common type of t1 and t2?'
  #
  # TODO: The current implementation should be optimized for performance
  #
  # @api public
  #
  def common_type(t1, t2)
    raise ArgumentError, 'two types expected' unless (is_ptype?(t1) || is_pnil?(t1)) && (is_ptype?(t2) || is_pnil?(t2))

    # TODO: This is not right since Scalar U Undef is Any
    # if either is nil, the common type is the other
    if is_pnil?(t1)
      return t2
    elsif is_pnil?(t2)
      return t1
    end

    # If either side is Unit, it is the other type
    if t1.is_a?(Types::PUnitType)
      return t2
    elsif t2.is_a?(Types::PUnitType)
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

    # when both are host-classes, reduce to PHostClass[] (since one was not assignable to the other)
    if t1.is_a?(Types::PHostClassType) && t2.is_a?(Types::PHostClassType)
      return Types::PHostClassType.new()
    end

    # when both are resources, reduce to Resource[T] or Resource[] (since one was not assignable to the other)
    if t1.is_a?(Types::PResourceType) && t2.is_a?(Types::PResourceType)
      result = Types::PResourceType.new()
      # only Resource[] unless the type name is the same
      if t1.type_name == t2.type_name then result.type_name = t1.type_name end
      # the cross assignability test above has already determined that they do not have the same type and title
      return result
    end

    # Integers have range, expand the range to the common range
    if t1.is_a?(Types::PIntegerType) && t2.is_a?(Types::PIntegerType)
      t1range = from_to_ordered(t1.from, t1.to)
      t2range = from_to_ordered(t2.from, t2.to)
      t = Types::PIntegerType.new()
      from = [t1range[0], t2range[0]].min
      to = [t1range[1], t2range[1]].max
      t.from = from unless from == TheInfinity
      t.to = to unless to == TheInfinity
      return t
    end

    # Floats have range, expand the range to the common range
    if t1.is_a?(Types::PFloatType) && t2.is_a?(Types::PFloatType)
      t1range = from_to_ordered(t1.from, t1.to)
      t2range = from_to_ordered(t2.from, t2.to)
      t = Types::PFloatType.new()
      from = [t1range[0], t2range[0]].min
      to = [t1range[1], t2range[1]].max
      t.from = from unless from == TheInfinity
      t.to = to unless to == TheInfinity
      return t
    end

    if t1.is_a?(Types::PStringType) && t2.is_a?(Types::PStringType)
      t = Types::PStringType.new()
      t.values = t1.values | t2.values unless t1.values.empty? || t2.values.empty?
      t.size_type = common_type(t1.size_type, t2.size_type) unless t1.size_type.nil? || t2.size_type.nil?
      return t
    end

    if t1.is_a?(Types::PPatternType) && t2.is_a?(Types::PPatternType)
      t = Types::PPatternType.new()
      # must make copies since patterns are contained types, not data-types
      t.patterns = (t1.patterns | t2.patterns).map(&:copy)
      return t
    end

    if t1.is_a?(Types::PEnumType) && t2.is_a?(Types::PEnumType)
      # The common type is one that complies with either set
      t = Types::PEnumType.new
      t.values = t1.values | t2.values
      return t
    end

    if t1.is_a?(Types::PVariantType) && t2.is_a?(Types::PVariantType)
      # The common type is one that complies with either set
      t = Types::PVariantType.new
      t.types = (t1.types | t2.types).map(&:copy)
      return t
    end

    if t1.is_a?(Types::PRegexpType) && t2.is_a?(Types::PRegexpType)
      # if they were identical, the general rule would return a parameterized regexp
      # since they were not, the result is a generic regexp type
      return Types::PPatternType.new()
    end

    if t1.is_a?(Types::PCallableType) && t2.is_a?(Types::PCallableType)
      # They do not have the same signature, and one is not assignable to the other,
      # what remains is the most general form of Callable
      return Types::PCallableType.new()
    end

    # Common abstract types, from most specific to most general
    if common_numeric?(t1, t2)
      return Types::PNumericType.new()
    end

    if common_scalar?(t1, t2)
      return Types::PScalarType.new()
    end

    if common_data?(t1,t2)
      return Types::PDataType.new()
    end

    # Meta types Type[Integer] + Type[String] => Type[Data]
    if t1.is_a?(Types::PType) && t2.is_a?(Types::PType)
      type = Types::PType.new()
      type.type = common_type(t1.type, t2.type)
      return type
    end

    # If both are Runtime types
    if t1.is_a?(Types::PRuntimeType) && t2.is_a?(Types::PRuntimeType)
      if t1.runtime == t2.runtime && t1.runtime_type_name == t2.runtime_type_name
        return t1
      end
      # finding the common super class requires that names are resolved to class
      # NOTE: This only supports runtime type of :ruby
      c1 = Types::ClassLoader.provide_from_type(t1)
      c2 = Types::ClassLoader.provide_from_type(t2)
      if c1 && c2
        c2_superclasses = superclasses(c2)
        superclasses(c1).each do|c1_super|
          c2_superclasses.each do |c2_super|
            if c1_super == c2_super
              return Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => c1_super.name)
            end
          end
        end
      end
    end

    # They better both be Any type, or the wrong thing was asked and nil is returned
    if t1.is_a?(Types::PAnyType) && t2.is_a?(Types::PAnyType)
      return Types::PAnyType.new()
    end
  end

  # Produces the superclasses of the given class, including the class
  def superclasses(c)
    result = [c]
    while s = c.superclass
      result << s
      c = s
    end
    result
  end

  # Produces a string representing the type
  # @api public
  #
  def string(t)
    @@string_visitor.visit_this_0(self, t)
  end

  # Produces a debug string representing the type (possibly with more information that the regular string format)
  # @api public
  #
  def debug_string(t)
    @@inspect_visitor.visit_this_0(self, t)
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
  def infer_Closure(o)
    o.type()
  end

  # @api private
  def infer_Function(o)
    o.class.dispatcher.to_type
  end

  # @api private
  def infer_Object(o)
    Types::PRuntimeType.new(:runtime => :ruby, :runtime_type_name => o.class.name)
  end

  # The type of all types is PType
  # @api private
  #
  def infer_PAnyType(o)
    type = Types::PType.new()
    type.type = o.copy
    type
  end

  # The type of all types is PType
  # This is the metatype short circuit.
  # @api private
  #
  def infer_PType(o)
    type = Types::PType.new()
    type.type = o.copy
    type
  end

  # @api private
  def infer_String(o)
    t = Types::PStringType.new()
    t.addValues(o)
    t.size_type = size_as_type(o)
    t
  end

  # @api private
  def infer_Float(o)
    t = Types::PFloatType.new()
    t.from = o
    t.to = o
    t
  end

  # @api private
  def infer_Integer(o)
    t = Types::PIntegerType.new()
    t.from = o
    t.to = o
    t
  end

  # @api private
  def infer_Regexp(o)
    t = Types::PRegexpType.new()
    t.pattern = o.source
    t
  end

  # @api private
  def infer_NilClass(o)
    Types::PUndefType.new()
  end

  # @api private
  # @param o [Proc]
  def infer_Proc(o)
    min = 0
    max = 0
    if o.respond_to?(:parameters)
      mapped_types = o.parameters.map do |p|
        param_t = Types::PAnyType.new
        case p[0]
        when :rest
          max = :default
          break param_t
        when :req
          min += 1
        end
        max += 1
      	param_t
      end
    else
      # Cannot correctly compute the signature in Ruby 1.8.7 because arity for
      # optional values is screwed up (there is no way to get the upper limit),
      # an optional looks the same as a varargs.
      arity = o.arity
      if arity < 0
        min = -arity - 1
        max = :default # i.e. infinite (which is wrong when there are optional - flaw in 1.8.7)
      else
        min = max = arity
      end
      mapped_types = Array.new(min) { Types::PAnyType.new }
    end
    if min == 0 || min != max
      mapped_types << min
      mapped_types << max
    end
    Types::TypeFactory.callable(*mapped_types)
  end

  # @api private
  def infer_PuppetProc(o)
    infer_Closure(o.closure)
  end

  # Inference of :default as PDefaultType, and all other are Ruby[Symbol]
  # @api private
  def infer_Symbol(o)
    case o
    when :default
      Types::PDefaultType.new()
    when :undef
      Types::PUndefType.new()
    else
      infer_Object(o)
    end
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
  # A Puppet::Parser::Resource, or Puppet::Resource
  #
  def infer_Resource(o)
    t = Types::PResourceType.new()
    t.type_name = o.type.to_s.downcase
    # Only Puppet::Resource can have a title that is a symbol :undef, a PResource cannot.
    # A mapping must be made to empty string. A nil value will result in an error later
    title = o.title
    t.title = (:undef == title  ? '' : title)
    type = Types::PType.new()
    type.type = t
    type
  end

  # @api private
  def infer_Array(o)
    type = Types::PArrayType.new()
    type.element_type =
    if o.empty?
      Types::PUndefType.new()
    else
      infer_and_reduce_type(o)
    end
    type.size_type = size_as_type(o)
    type
  end

  # @api private
  def infer_Hash(o)
    type = Types::PHashType.new()
    if o.empty?
      ktype = Types::PUndefType.new()
      etype = Types::PUndefType.new()
    else
      ktype = infer_and_reduce_type(o.keys())
      etype = infer_and_reduce_type(o.values())
    end
    type.key_type = ktype
    type.element_type = etype
    type.size_type = size_as_type(o)
    type
  end

  def size_as_type(collection)
    size = collection.size
    t = Types::PIntegerType.new()
    t.from = size
    t.to = size
    t
  end

  # Common case for everything that intrinsically only has a single type
  def infer_set_Object(o)
    infer(o)
  end

  def infer_set_Array(o)
    if o.empty?
      type = Types::PArrayType.new()
      type.element_type = Types::PUndefType.new()
      type.size_type = size_as_type(o)
    else
      type = Types::PTupleType.new()
      type.types = o.map() {|x| infer_set(x) }
    end
    type
  end

  def infer_set_Hash(o)
    if o.empty?
      type = Types::PHashType.new
      type.key_type = Types::PUndefType.new
      type.element_type = Types::PUndefType.new
      type.size_type = size_as_type(o)
    elsif o.keys.all? {|k| instance_of_PStringType(@non_empty_string_t, k) }
      type = Types::PStructType.new
      type.elements = o.map do |k,v|
        element = Types::PStructElement.new
        element.key_type = infer_String(k)
        element.value_type = infer_set(v)
        element
      end
    else
      type = Types::PHashType.new
      ktype = Types::PVariantType.new
      ktype.types = o.keys.map {|k| infer_set(k) }
      etype = Types::PVariantType.new
      etype.types = o.values.map {|e| infer_set(e) }
      type.key_type = unwrap_single_variant(ktype)
      type.element_type = unwrap_single_variant(etype)
      type.size_type = size_as_type(o)
    end
    type
  end

  def unwrap_single_variant(possible_variant)
    if possible_variant.is_a?(Types::PVariantType) && possible_variant.types.size == 1
      possible_variant.types[0]
    else
      possible_variant
    end
  end

  # False in general type calculator
  # @api private
  def assignable_Object(t, t2)
    false
  end

  # @api private
  def assignable_PAnyType(t, t2)
    t2.is_a?(Types::PAnyType)
  end

  # @api private
  def assignable_PNotUndefType(t, t2)
    !assignable?(t2, @nil_t) && (t.type.nil? || assignable?(t.type, t2))
  end

  # @api private
  def assignable_PUndefType(t, t2)
    # Only undef/nil is assignable to nil type
    t2.is_a?(Types::PUndefType)
  end

  # Anything is assignable to a Unit type
  # @api private
  def assignable_PUnitType(t, t2)
    true
  end

  # @api private
  def assignable_PDefaultType(t, t2)
    # Only default is assignable to default type
    t2.is_a?(Types::PDefaultType)
  end

  # @api private
  def assignable_PScalarType(t, t2)
    t2.is_a?(Types::PScalarType)
  end

  # @api private
  def assignable_PNumericType(t, t2)
    t2.is_a?(Types::PNumericType)
  end

  # @api private
  def assignable_PIntegerType(t, t2)
    return false unless t2.is_a?(Types::PIntegerType)
    trange =  from_to_ordered(t.from, t.to)
    t2range = from_to_ordered(t2.from, t2.to)
    # If t2 min and max are within the range of t
    trange[0] <= t2range[0] && trange[1] >= t2range[1]
  end

  # Transform int range to a size constraint
  # if range == nil the constraint is 1,1
  # if range.from == nil min size = 1
  # if range.to == nil max size == Infinity
  #
  def size_range(range)
    return [1,1] if range.nil?
    from = range.from
    to = range.to
    x = from.nil? ? 1 : from
    y = to.nil? ? TheInfinity : to
    [x, y]
  end

  # @api private
  def from_to_ordered(from, to)
    x = (from.nil? || from == :default) ? -TheInfinity : from
    y = (to.nil? || to == :default) ? TheInfinity : to
    if x < y
      [x, y]
    else
      [y, x]
    end
  end

  # @api private
  def assignable_PVariantType(t, t2)
    # Data is a specific variant
    t2 = @data_variant_t if t2.is_a?(Types::PDataType)
    if t2.is_a?(Types::PVariantType)
      # A variant is assignable if all of its options are assignable to one of this type's options
      return true if t == t2
      t2.types.all? do |other|
        # if the other is a Variant, all of its options, but be assignable to one of this type's options
        other = other.is_a?(Types::PDataType) ? @data_variant_t : other
        if other.is_a?(Types::PVariantType)
          assignable?(t, other)
        else
          t.types.any? {|option_t| assignable?(option_t, other) }
        end
      end
    else
      # A variant is assignable if t2 is assignable to any of its types
      t.types.any? { |option_t| assignable?(option_t, t2) }
    end
  end

  # Catch all not callable combinations
  def callable_Object(o, callable_t)
    false
  end

  def callable_PTupleType(args_tuple, callable_t)
    if args_tuple.size_type
      raise ArgumentError, "Callable tuple may not have a size constraint when used as args"
    end
    # Assume no block was given - i.e. it is nil, and its type is PUndefType
    block_t = @nil_t
    if self.class.is_kind_of_callable?(args_tuple.types.last)
      # a split is needed to make it possible to use required, optional, and varargs semantics
      # of the tuple type.
      #
      args_tuple = args_tuple.copy
      # to drop the callable, it must be removed explicitly since this is an rgen array
      args_tuple.removeTypes(block_t = args_tuple.types.last())
    else
      # no block was given, if it is required, the below will fail
    end
    # unless argument types match parameter types
    return false unless assignable?(callable_t.param_types, args_tuple)
    # can the given block be *called* with a signature requirement specified by callable_t?
    assignable?(callable_t.block_type || @nil_t, block_t)
  end

  # @api private
  def self.is_kind_of_callable?(t, optional = true)
    case t
    when Types::PCallableType
      true
    when Types::POptionalType
      optional && is_kind_of_callable?(t.optional_type, optional)
    when Types::PVariantType
      t.types.all? {|t2| is_kind_of_callable?(t2, optional) }
    else
      false
    end
  end

  # @api private
  def self.is_kind_of_optional?(t, optional = true)
    case t
    when Types::POptionalType
      true
    when Types::PVariantType
      t.types.all? {|t2| is_kind_of_optional?(t2, optional) }
    else
      false
    end
  end

  def callable_PArrayType(args_array, callable_t)
    return false unless assignable?(callable_t.param_types, args_array)
    # does not support calling with a block, but have to check that callable is ok with missing block
    assignable?(callable_t.block_type || @nil_t, @nil_t)
  end

  def callable_PUndefType(nil_t, callable_t)
    # if callable_t is Optional (or indeed PUndefType), this means that 'missing callable' is accepted
    assignable?(callable_t, nil_t)
  end

  def callable_PCallableType(given_callable_t, required_callable_t)
    # If the required callable is euqal or more specific than the given, the given is callable
    assignable?(required_callable_t, given_callable_t)
  end

  def max(a,b)
    a >=b ? a : b
  end

  def min(a,b)
    a <= b ? a : b
  end

  def assignable_PTupleType(t, t2)
    return true if t == t2 || t.types.empty? && (t2.is_a?(Types::PArrayType))
    size_t = t.size_type || Puppet::Pops::Types::TypeFactory.range(*t.size_range)

    if t2.is_a?(Types::PTupleType)
      size_t2 = t2.size_type || Puppet::Pops::Types::TypeFactory.range(*t2.size_range)

      # not assignable if the number of types in t2 is outside number of types in t1
      if assignable?(size_t, size_t2)
        t2.types.size.times do |index|
          return false unless assignable?((t.types[index] || t.types[-1]), t2.types[index])
        end
        return true
      else
        return false
      end
    elsif t2.is_a?(Types::PArrayType)
      t2_entry = t2.element_type

      # Array of anything can not be assigned (unless tuple is tuple of anything) - this case
      # was handled at the top of this method.
      #
      return false if t2_entry.nil?
      size_t = t.size_type || Puppet::Pops::Types::TypeFactory.range(*t.size_range)
      size_t2 = t2.size_type || @collection_default_size_t
      return false unless assignable?(size_t, size_t2)
      min(t.types.size, size_t2.range()[1]).times do |index|
        return false unless assignable?((t.types[index] || t.types[-1]), t2_entry)
      end
      true
    else
      false
    end
  end

  # Produces the tuple entry at the given index given a tuple type, its from/to constraints on the last
  # type, and an index.
  # Produces nil if the index is out of bounds
  # from must be less than to, and from may not be less than 0
  #
  # @api private
  #
  def tuple_entry_at(tuple_t, from, to, index)
    regular = (tuple_t.types.size - 1)
    if index < regular
      tuple_t.types[index]
    elsif index < regular + to
      # in the varargs part
      tuple_t.types[-1]
    else
      nil
    end
  end

  # @api private
  #
  def assignable_PStructType(t, t2)
    if t2.is_a?(Types::PStructType)
      h2 = t2.hashed_elements
      matched = 0
      t.elements.all? do |e1|
        e2 = h2[e1.name]
        if e2.nil?
          assignable?(e1.key_type, @nil_t)
        else
          matched += 1
          assignable?(e1.key_type, e2.key_type) && assignable?(e1.value_type, e2.value_type)
        end
      end && matched == h2.size
    elsif t2.is_a?(Types::PHashType)
      required = 0
      required_elements_assignable = t.elements.all? do |e|
        if assignable?(e.key_type, @nil_t)
          true
        else
          required += 1
          assignable?(e.value_type, t2.element_type)
        end
      end
      if required_elements_assignable
        size_t2 = t2.size_type || @collection_default_size_t
        size_t = Types::PIntegerType.new
        size_t.from = required
        size_t.to = t.elements.size
        assignable_PIntegerType(size_t, size_t2)
      end
    else
      false
    end
  end

  # @api private
  def assignable_POptionalType(t, t2)
    return true if t2.is_a?(Types::PUndefType)
    return true if t.optional_type.nil?
    if t2.is_a?(Types::POptionalType)
      assignable?(t.optional_type, t2.optional_type || @t)
    else
      assignable?(t.optional_type, t2)
    end
  end

  # @api private
  def assignable_PEnumType(t, t2)
    return true if t == t2
    if t.values.empty?
      return true if t2.is_a?(Types::PStringType) || t2.is_a?(Types::PEnumType) || t2.is_a?(Types::PPatternType)
    end
    case t2
    when Types::PStringType
      # if the set of strings are all found in the set of enums
      !t2.values.empty?() && t2.values.all? { |s| t.values.any? { |e| e == s }}
    when Types::PVariantType
      t2.types.all? {|variant_t| assignable_PEnumType(t, variant_t) }
    when Types::PEnumType
      # empty means any enum
      return true if t.values.empty?
      !t2.values.empty? && t2.values.all? { |s| t.values.any? {|e| e == s }}
    else
      false
    end
  end

  # @api private
  def assignable_PStringType(t, t2)
    if t.values.empty?
      # A general string is assignable by any other string or pattern restricted string
      # if the string has a size constraint it does not match since there is no reasonable way
      # to compute the min/max length a pattern will match. For enum, it is possible to test that
      # each enumerator value is within range
      size_t = t.size_type || @collection_default_size_t
      case t2
      when Types::PStringType
        # true if size compliant
        size_t2 = t2.size_type || @collection_default_size_t
        assignable_PIntegerType(size_t, size_t2)

      when Types::PPatternType
        # true if size constraint is at least 0 to +Infinity (which is the same as the default)
        assignable_PIntegerType(size_t, @collection_default_size_t)

      when Types::PEnumType
        if t2.values && !t2.values.empty?
          # true if all enum values are within range
          min, max = t2.values.map(&:size).minmax
          trange =  from_to_ordered(size_t.from, size_t.to)
          t2range = [min, max]
          # If t2 min and max are within the range of t
          trange[0] <= t2range[0] && trange[1] >= t2range[1]
        else
          # enum represents all enums, and thus all strings, a sized constrained string can thus not
          # be assigned any enum (unless it is max size).
          assignable_PIntegerType(size_t, @collection_default_size_t)
        end
      else
        # no other type matches string
        false
      end
    elsif t2.is_a?(Types::PStringType)
      # A specific string acts as a set of strings - must have exactly the same strings
      # In this case, size does not matter since the definition is very precise anyway
      Set.new(t.values) == Set.new(t2.values)
    else
      # All others are false, since no other type describes the same set of specific strings
      false
    end
  end

  # @api private
  def assignable_PPatternType(t, t2)
    return true if t == t2
    case t2
    when Types::PStringType, Types::PEnumType
      values = t2.values
    when Types::PVariantType
      return t2.types.all? {|variant_t| assignable_PPatternType(t, variant_t) }
    when Types::PPatternType
      return t.patterns.empty? ? true : false
    else
      return false
    end

    if t2.values.empty?
      # Strings / Enums (unknown which ones) cannot all match a pattern, but if there is no pattern it is ok
      # (There should really always be a pattern, but better safe than sorry).
      return t.patterns.empty? ? true : false
    end
    # all strings in String/Enum type must match one of the patterns in Pattern type,
    # or Pattern represents all Patterns == all Strings
    regexps = t.patterns.map {|p| p.regexp }
    regexps.empty? || t2.values.all? { |v| regexps.any? {|re| re.match(v) } }
  end

  # @api private
  def assignable_PFloatType(t, t2)
    return false unless t2.is_a?(Types::PFloatType)
    trange =  from_to_ordered(t.from, t.to)
    t2range = from_to_ordered(t2.from, t2.to)
    # If t2 min and max are within the range of t
    trange[0] <= t2range[0] && trange[1] >= t2range[1]
  end

  # @api private
  def assignable_PBooleanType(t, t2)
    t2.is_a?(Types::PBooleanType)
  end

  # @api private
  def assignable_PRegexpType(t, t2)
    t2.is_a?(Types::PRegexpType) && (t.pattern.nil? || t.pattern == t2.pattern)
  end

  # @api private
  def assignable_PCallableType(t, t2)
    return false unless t2.is_a?(Types::PCallableType)
    # nil param_types means, any other Callable is assignable
    return true if t.param_types.nil?

    # NOTE: these tests are made in reverse as it is calling the callable that is constrained
    # (it's lower bound), not its upper bound
    return false unless assignable?(t2.param_types, t.param_types)
    # names are ignored, they are just information
    # Blocks must be compatible
    this_block_t = t.block_type || @nil_t
    that_block_t = t2.block_type || @nil_t
    assignable?(that_block_t, this_block_t)

  end

  # @api private
  def assignable_PCollectionType(t, t2)
    size_t = t.size_type || @collection_default_size_t
    case t2
    when Types::PCollectionType
      size_t2 = t2.size_type || @collection_default_size_t
      assignable_PIntegerType(size_t, size_t2)
    when Types::PTupleType
      # compute the tuple's min/max size, and check if that size matches
      from, to = size_range(t2.size_type)
      t2s = Types::PIntegerType.new()
      t2s.from = t2.types.size - 1 + from
      t2s.to = t2.types.size - 1 + to
      assignable_PIntegerType(size_t, t2s)
    when Types::PStructType
      from = to = t2.elements.size
      t2s = Types::PIntegerType.new()
      t2s.from = from
      t2s.to = to
      assignable_PIntegerType(size_t, t2s)
    else
      false
    end
  end

  # @api private
  def assignable_PType(t, t2)
    return false unless t2.is_a?(Types::PType)
    return true if t.type.nil? # wide enough to handle all types
    return false if t2.type.nil? # wider than t
    assignable?(t.type, t2.type)
  end

  # Array is assignable if t2 is an Array and t2's element type is assignable, or if t2 is a Tuple
  # where 
  # @api private
  def assignable_PArrayType(t, t2)
    if t2.is_a?(Types::PArrayType)
      return false unless t.element_type.nil? || assignable?(t.element_type, t2.element_type || @t)
      assignable_PCollectionType(t, t2)

    elsif t2.is_a?(Types::PTupleType)
      return false unless t.element_type.nil? || t2.types.all? {|t2_element| assignable?(t.element_type, t2_element) }
      t2_regular = t2.types[0..-2]
      t2_ranged = t2.types[-1]
      t2_from, t2_to = size_range(t2.size_type)
      t2_required = t2_regular.size + t2_from

      t_entry = t.element_type

      # Tuple of anything can not be assigned (unless array is tuple of anything) - this case
      # was handled at the top of this method.
      #
      return false if t_entry.nil?

      # array type may be size constrained
      size_t = t.size_type || @collection_default_size_t
      min, max = size_t.range
      # Tuple with fewer min entries can not be assigned
      return false if t2_required < min
      # Tuple with more optionally available entries can not be assigned
      return false if t2_regular.size + t2_to > max
      # each tuple type must be assignable to the element type
      t2_required.times do |index|
        t2_entry = tuple_entry_at(t2, t2_from, t2_to, index)
        return false unless assignable?(t_entry, t2_entry)
      end
      # ... and so must the last, possibly optional (ranged) type
      return assignable?(t_entry, t2_ranged)
    else
      false
    end
  end

  # Hash is assignable if t2 is a Hash and t2's key and element types are assignable
  # @api private
  def assignable_PHashType(t, t2)
    case t2
    when Types::PHashType
      return true if (t.size_type.nil? || t.size_type.from == 0) && t2.is_the_empty_hash?
      return false unless t.key_type.nil? || assignable?(t.key_type, t2.key_type || @t)
      return false unless t.element_type.nil? || assignable?(t.element_type, t2.element_type || @t)
      assignable_PCollectionType(t, t2)
    when Types::PStructType
      # hash must accept String as key type
      # hash must accept all value types
      # hash must accept the size of the struct
      size_t = t.size_type || @collection_default_size_t
      min, max = size_t.range
      struct_size = t2.elements.size
      key_type = t.key_type
      element_type = t.element_type
      ( struct_size >= min && struct_size <= max &&
        t2.elements.all? {|e| (key_type.nil? || instance_of(key_type, e.name)) && (element_type.nil? || assignable?(element_type, e.value_type)) })
    else
      false
    end
  end

  # @api private
  def assignable_PCatalogEntryType(t1, t2)
    t2.is_a?(Types::PCatalogEntryType)
  end

  # @api private
  def assignable_PHostClassType(t1, t2)
    return false unless t2.is_a?(Types::PHostClassType)
    # Class = Class[name}, Class[name] != Class
    return true if t1.class_name.nil?
    # Class[name] = Class[name]
    return t1.class_name == t2.class_name
  end

  # @api private
  def assignable_PResourceType(t1, t2)
    return false unless t2.is_a?(Types::PResourceType)
    return true if t1.type_name.nil?
    return false if t1.type_name != t2.type_name
    return true if t1.title.nil?
    return t1.title == t2.title
  end

  # Data is assignable by other Data and by Array[Data] and Hash[Scalar, Data]
  # @api private
  def assignable_PDataType(t, t2)
    # We cannot put the NotUndefType[Data] in the @data_variant_t since that causes an endless recursion
    case t2
    when Types::PDataType
      true
    when Types::PNotUndefType
      assignable?(t, t2.type || @t)
    else
      assignable?(@data_variant_t, t2)
    end
  end

  # Assignable if t2's has the same runtime and the runtime name resolves to
  # a class that is the same or subclass of t1's resolved runtime type name
  # @api private
  def assignable_PRuntimeType(t1, t2)
    return false unless t2.is_a?(Types::PRuntimeType)
    return false unless t1.runtime == t2.runtime
    return true if t1.runtime_type_name.nil?   # t1 is wider
    return false if t2.runtime_type_name.nil?  # t1 not nil, so t2 can not be wider

    # NOTE: This only supports Ruby, must change when/if the set of runtimes is expanded
    c1 = class_from_string(t1.runtime_type_name)
    c2 = class_from_string(t2.runtime_type_name)
    return false unless c1.is_a?(Class) && c2.is_a?(Class)
    !!(c2 <= c1)
  end

  # @api private
  def debug_string_Object(t)
    string(t)
  end

  # @api private
  def string_PType(t)
    if t.type.nil?
      "Type"
    else
      "Type[#{string(t.type)}]"
    end
  end

  # @api private
  def string_NilClass(t)     ; '?'       ; end

  # @api private
  def string_String(t)       ; t         ; end

  # @api private
  def string_Symbol(t)       ; t.to_s    ; end

  def string_PAnyType(t)     ; "Any"     ; end

  # @api private
  def string_PUndefType(t)     ; 'Undef'   ; end

  # @api private
  def string_PDefaultType(t) ; 'Default' ; end

  # @api private
  def string_PBooleanType(t) ; "Boolean" ; end

  # @api private
  def string_PScalarType(t)  ; "Scalar"  ; end

  # @api private
  def string_PDataType(t)    ; "Data"    ; end

  # @api private
  def string_PNumericType(t) ; "Numeric" ; end

  # @api private
  def string_PIntegerType(t)
    range = range_array_part(t)
    unless range.empty?
      "Integer[#{range.join(', ')}]"
    else
      "Integer"
    end
  end

  # Produces a string from an Integer range type that is used inside other type strings
  # @api private
  def range_array_part(t)
    return [] if t.nil? || (t.from.nil? && t.to.nil?)
    [t.from.nil? ? 'default' : t.from , t.to.nil? ? 'default' : t.to ]
  end

  # @api private
  def string_PFloatType(t)
    range = range_array_part(t)
    unless range.empty?
      "Float[#{range.join(', ')}]"
    else
      "Float"
    end
  end

  # @api private
  def string_PRegexpType(t)
    t.pattern.nil? ? "Regexp" : "Regexp[#{t.regexp.inspect}]"
  end

  # @api private
  def string_PStringType(t)
    # skip values in regular output - see debug_string
    range = range_array_part(t.size_type)
    unless range.empty?
      "String[#{range.join(', ')}]"
    else
      "String"
    end
  end

  # @api private
  def debug_string_PStringType(t)
    range = range_array_part(t.size_type)
    range_part = range.empty? ? '' : '[' << range.join(' ,') << '], '
    "String[" << range_part << (t.values.map {|s| "'#{s}'" }).join(', ') << ']'
  end

  # @api private
  def string_PEnumType(t)
    return "Enum" if t.values.empty?
    "Enum[" << t.values.map {|s| "'#{s}'" }.join(', ') << ']'
  end

  # @api private
  def string_PVariantType(t)
    return "Variant" if t.types.empty?
    "Variant[" << t.types.map {|t2| string(t2) }.join(', ') << ']'
  end

  # @api private
  def string_PTupleType(t)
    range = range_array_part(t.size_type)
    return "Tuple" if t.types.empty?
    s = "Tuple[" << t.types.map {|t2| string(t2) }.join(', ')
    unless range.empty?
      s << ", " << range.join(', ')
    end
    s << "]"
    s
  end

  # @api private
  def string_PCallableType(t)
    # generic
    return "Callable" if t.param_types.nil?

    if t.param_types.types.empty?
      range = [0, 0]
    else
      range = range_array_part(t.param_types.size_type)
    end
    # translate to string, and skip Unit types
    types = t.param_types.types.map {|t2| string(t2) unless t2.class == Types::PUnitType }.compact

    s = "Callable[" << types.join(', ')
    unless range.empty?
      (s << ', ') unless types.empty?
      s << range.join(', ')
    end
    # Add block T last (after min, max) if present)
    #
    unless t.block_type.nil?
      (s << ', ') unless types.empty? && range.empty?
      s << string(t.block_type)
    end
    s << "]"
    s
  end

  # @api private
  def string_PStructType(t)
    return "Struct" if t.elements.empty?
    "Struct[{" << t.elements.map {|element| string(element) }.join(', ') << "}]"
  end

  def string_PStructElement(t)
    k = t.key_type
    value_optional = assignable?(t.value_type, @nil_t)
    key_string =
      if k.is_a?(Types::POptionalType)
        # Output as literal String
        value_optional ? "'#{t.name}'" : string(k)
      else
        value_optional ? "NotUndef['#{t.name}']" : "'#{t.name}'"
      end
    "#{key_string}=>#{string(t.value_type)}"
  end

  # @api private
  def string_PPatternType(t)
    return "Pattern" if t.patterns.empty?
    "Pattern[" << t.patterns.map {|s| "#{s.regexp.inspect}" }.join(', ') << ']'
  end

  # @api private
  def string_PCollectionType(t)
    range = range_array_part(t.size_type)
    unless range.empty?
      "Collection[#{range.join(', ')}]"
    else
      "Collection"
    end
  end

  # @api private
  def string_PUnitType(t)
    "Unit"
  end

  # @api private
  def string_PRuntimeType(t)   ; "Runtime[#{string(t.runtime)}, #{string(t.runtime_type_name)}]"  ; end

  # @api private
  def string_PArrayType(t)
    parts = [string(t.element_type)] + range_array_part(t.size_type)
    "Array[#{parts.join(', ')}]"
  end

  # @api private
  def string_PHashType(t)
    parts = [string(t.key_type), string(t.element_type)] + range_array_part(t.size_type)
    "Hash[#{parts.join(', ')}]"
  end

  # @api private
  def string_PCatalogEntryType(t)
    "CatalogEntry"
  end

  # @api private
  def string_PHostClassType(t)
    if t.class_name
      "Class[#{t.class_name}]"
    else
      "Class"
    end
  end

  # @api private
  def string_PResourceType(t)
    if t.type_name
      if t.title
        "#{capitalize_segments(t.type_name)}['#{t.title}']"
      else
        capitalize_segments(t.type_name)
      end
    else
      "Resource"
    end
  end

  # @api private
  def string_PNotUndefType(t)
    contained_type = t.type
    if contained_type.nil? || contained_type.class == Puppet::Pops::Types::PAnyType
      'NotUndef'
    else
      if contained_type.is_a?(Puppet::Pops::Types::PStringType) && contained_type.values.size == 1
        "NotUndef['#{contained_type.values[0]}']"
      else
        "NotUndef[#{string(contained_type)}]"
      end
    end
  end

  def string_POptionalType(t)
    optional_type = t.optional_type
    if optional_type.nil?
      "Optional"
    else
      if optional_type.is_a?(Puppet::Pops::Types::PStringType) && optional_type.values.size == 1
        "Optional['#{optional_type.values[0]}']"
      else
        "Optional[#{string(optional_type)}]"
      end
    end
  end

  # Catches all non enumerable types
  # @api private
  def enumerable_Object(o)
    nil
  end

  # @api private
  def enumerable_PIntegerType(t)
    # Not enumerable if representing an infinite range
    return nil if t.size == TheInfinity
    t
  end

  def self.copy_as_tuple(t)
    case t
    when Types::PTupleType
      t.copy
    when Types::PArrayType
      # transform array to tuple
      result = Types::PTupleType.new
      result.addTypes(t.element_type.copy)
      result.size_type = t.size_type.nil? ? nil : t.size_type.copy
      result
    else
      raise ArgumentError, "Internal Error: Only Array and Tuple can be given to copy_as_tuple"
    end
  end

  private

  NAME_SEGMENT_SEPARATOR = '::'.freeze

  def capitalize_segments(s)
    s.split(NAME_SEGMENT_SEPARATOR).map(&:capitalize).join(NAME_SEGMENT_SEPARATOR)
  end

  def class_from_string(str)
    begin
      str.split(NAME_SEGMENT_SEPARATOR).inject(Object) do |memo, name_segment|
        memo.const_get(name_segment)
      end
    rescue NameError
      return nil
    end
  end

  def common_data?(t1, t2)
    assignable?(@data_t, t1) && assignable?(@data_t, t2)
  end

  def common_scalar?(t1, t2)
    assignable?(@scalar_t, t1) && assignable?(@scalar_t, t2)
  end

  def common_numeric?(t1, t2)
    assignable?(@numeric_t, t1) && assignable?(@numeric_t, t2)
  end

end
