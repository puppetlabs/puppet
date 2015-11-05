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
  def self.generalize(o)
    singleton.generalize(o)
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

  # @return [TypeCalculator] the singleton instance
  #
  # @api private
  def self.singleton
    @tc_instance ||= new
  end

  # @api public
  #
  def initialize
    @@infer_visitor ||= Puppet::Pops::Visitor.new(nil, 'infer',0,0)
    @@string_visitor ||= Puppet::Pops::Visitor.new(nil, 'string',0,0)
    @@inspect_visitor ||= Puppet::Pops::Visitor.new(nil, 'debug_string',0,0)
    @@extract_visitor ||= Puppet::Pops::Visitor.new(nil, 'extract',0,0)
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
    if (klazz.respond_to?(:inject) && klazz.method(:inject).arity == -4) || klazz.instance_method(:initialize).arity == 0
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
    if t.is_a?(Module)
      t = type(t)
    end
    t.is_a?(Types::PAnyType) ? t.assignable?(t2) : false
 end

  # Returns an enumerable if the t represents something that can be iterated
  def enumerable(t)
    # Only PIntegerTypes are enumerable and only if not representing an infinite range
    t.is_a?(Types::PIntegerType) && t.size < Float::INFINITY ? t : nil
  end

  # Answers, does the given callable accept the arguments given in args (an array or a tuple)
  #
  def callable?(callable, args)
    callable.is_a?(Types::PAnyType) && callable.callable?(args)
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
  # @param c [Module] the class for which a puppet type is wanted
  # @api public
  #
  def type(c)
    raise ArgumentError, 'Argument must be a Module' unless c.is_a? Module

    # Can't use a visitor here since we don't have an instance of the class
    case
    when c <= Integer
      type = Types::PIntegerType::DEFAULT
    when c == Float
      type = Types::PFloatType::DEFAULT
    when c == Numeric
      type = Types::PNumericType::DEFAULT
    when c == String
      type = Types::PStringType::DEFAULT
    when c == Regexp
      type = Types::PRegexpType::DEFAULT
    when c == NilClass
      type = Types::PUndefType::DEFAULT
    when c == FalseClass, c == TrueClass
      type = Types::PBooleanType::DEFAULT
    when c == Class
      type = Types::PType::DEFAULT
    when c == Array
      # Assume array of data values
      type = Types::PArrayType::DATA
    when c == Hash
      # Assume hash with scalar keys and data values
      type = Types::PHashType::DATA
   else
      type = Types::PRuntimeType.new(:ruby, c.name)
    end
    type
  end

  # Generalizes value specific types. The generalized type is returned.
  # @api public
  def generalize(o)
    o.is_a?(Types::PAnyType) ? o.generalize : o
  end

  # Answers 'what is the single common Puppet Type describing o', or if o is an Array or Hash, what is the
  # single common type of the elements (or keys and elements for a Hash).
  # @api public
  #
  def infer(o)
    # Optimize the most common cases into direct calls.
    case o
    when String
      infer_String(o)
    when Integer
      infer_Integer(o)
    when Array
      infer_Array(o)
    when Hash
      infer_Hash(o)
    when Puppet::Pops::Evaluator::PuppetProc
      infer_PuppetProc(o)
    else
      @@infer_visitor.visit_this_0(self, o)
    end
  end

  def infer_generic(o)
    generalize(infer(o))
  end

  # Answers 'what is the set of Puppet Types of o'
  # @api public
  #
  def infer_set(o)
    case o
      when Array
        infer_set_Array(o)
      when Hash
        infer_set_Hash(o)
      else
        infer_set_Object(o)
    end
  end

  # Answers 'is o an instance of type t'
  # @api public
  #
  def self.instance?(t, o)
    singleton.instance?(t,o)
  end

  # Answers 'is o an instance of type t'
  # @api public
  #
  def instance?(t, o)
    if t.is_a?(Module)
      t = type(t)
    end
    t.is_a?(Types::PAnyType) ? t.instance?(o) : false
  end

  # Answers if t is a puppet type
  # @api public
  #
  def is_ptype?(t)
    t.is_a?(Types::PAnyType)
  end

  # Answers if t represents the puppet type PUndefType
  # @api public
  #
  def is_pnil?(t)
    t.nil? || t.is_a?(Types::PUndefType)
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
      return Types::PArrayType.new(common_type(t1.element_type, t2.element_type))
    end

    # when both are hashes, return a hash with common key- and element type
    if t1.is_a?(Types::PHashType) && t2.is_a?(Types::PHashType)
      key_type = common_type(t1.key_type, t2.key_type)
      element_type = common_type(t1.element_type, t2.element_type)
      return Types::PHashType.new(key_type, element_type)
    end

    # when both are host-classes, reduce to PHostClass[] (since one was not assignable to the other)
    if t1.is_a?(Types::PHostClassType) && t2.is_a?(Types::PHostClassType)
      return Types::PHostClassType::DEFAULT
    end

    # when both are resources, reduce to Resource[T] or Resource[] (since one was not assignable to the other)
    if t1.is_a?(Types::PResourceType) && t2.is_a?(Types::PResourceType)
      # only Resource[] unless the type name is the same
      return t1.type_name == t2.type_name ?  Types::PResourceType.new(t1.type_name, nil) : Types::PResourceType::DEFAULT
    end

    # Integers have range, expand the range to the common range
    if t1.is_a?(Types::PIntegerType) && t2.is_a?(Types::PIntegerType)
      return Types::PIntegerType.new([t1.numeric_from, t2.numeric_from].min, [t1.numeric_to, t2.numeric_to].max)
    end

    # Floats have range, expand the range to the common range
    if t1.is_a?(Types::PFloatType) && t2.is_a?(Types::PFloatType)
      return Types::PFloatType.new([t1.numeric_from, t2.numeric_from].min, [t1.numeric_to, t2.numeric_to].max)
    end

    if t1.is_a?(Types::PStringType) && t2.is_a?(Types::PStringType)
      common_size_type = common_type(t1.size_type, t2.size_type) unless t1.size_type.nil? || t2.size_type.nil?
      common_strings = t1.values.empty? || t2.values.empty? ? [] : t1.values | t2.values
      return Types::PStringType.new(common_size_type, common_strings)
    end

    if t1.is_a?(Types::PPatternType) && t2.is_a?(Types::PPatternType)
      return Types::PPatternType.new(t1.patterns | t2.patterns)
    end

    if t1.is_a?(Types::PEnumType) && t2.is_a?(Types::PEnumType)
      # The common type is one that complies with either set
      return Types::PEnumType.new(t1.values | t2.values)
    end

    if t1.is_a?(Types::PVariantType) && t2.is_a?(Types::PVariantType)
      # The common type is one that complies with either set
      return Types::PVariantType.new(t1.types | t2.types)
    end

    if t1.is_a?(Types::PRegexpType) && t2.is_a?(Types::PRegexpType)
      # if they were identical, the general rule would return a parameterized regexp
      # since they were not, the result is a generic regexp type
      return Types::PPatternType::DEFAULT
    end

    if t1.is_a?(Types::PCallableType) && t2.is_a?(Types::PCallableType)
      # They do not have the same signature, and one is not assignable to the other,
      # what remains is the most general form of Callable
      return Types::PCallableType::DEFAULT
    end

    # Common abstract types, from most specific to most general
    if common_numeric?(t1, t2)
      return Types::PNumericType::DEFAULT
    end

    if common_scalar?(t1, t2)
      return Types::PScalarType::DEFAULT
    end

    if common_data?(t1,t2)
      return Types::PDataType::DEFAULT
    end

    # Meta types Type[Integer] + Type[String] => Type[Data]
    if t1.is_a?(Types::PType) && t2.is_a?(Types::PType)
      return Types::PType.new(common_type(t1.type, t2.type))
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
              return Types::PRuntimeType.new(:ruby, c1_super.name)
            end
          end
        end
      end
    end

    # They better both be Any type, or the wrong thing was asked and nil is returned
    t1.is_a?(Types::PAnyType) && t2.is_a?(Types::PAnyType) ? Types::PAnyType::DEFAULT : nil
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
    if t.is_a?(Module)
      t = type(t)
    end
    @@string_visitor.visit_this_0(self, t)
  end

  # Produces a debug string representing the type (possibly with more information that the regular string format)
  # @api public
  #
  def debug_string(t)
    if t.is_a?(Module)
      t = type(t)
    end
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
    reduce_type(enumerable.map {|o| infer(o) })
  end

  # The type of all modules is PType
  # @api private
  #
  def infer_Module(o)
    Types::PType::new(Types::PRuntimeType.new(:ruby, o.name))
  end

  # @api private
  def infer_Closure(o)
    o.type
  end

  # @api private
  def infer_Function(o)
    o.class.dispatcher.to_type
  end

  # @api private
  def infer_Object(o)
    Types::PRuntimeType.new(:ruby, o.class.name)
  end

  # The type of all types is PType
  # @api private
  #
  def infer_PAnyType(o)
    Types::PType.new(o)
  end

  # The type of all types is PType
  # This is the metatype short circuit.
  # @api private
  #
  def infer_PType(o)
    Types::PType.new(o)
  end

  # @api private
  def infer_String(o)
    Types::PStringType.new(size_as_type(o), [o])
  end

  # @api private
  def infer_Float(o)
    Types::PFloatType.new(o, o)
  end

  # @api private
  def infer_Integer(o)
    Types::PIntegerType.new(o, o)
  end

  # @api private
  def infer_Regexp(o)
    Types::PRegexpType.new(o.source)
  end

  # @api private
  def infer_NilClass(o)
    Types::PUndefType::DEFAULT
  end

  # @api private
  # @param o [Proc]
  def infer_Proc(o)
    min = 0
    max = 0
    mapped_types = o.parameters.map do |p|
      case p[0]
      when :rest
        max = :default
        break Types::PAnyType::DEFAULT
      when :req
        min += 1
      end
      max += 1
      Types::PAnyType::DEFAULT
    end
    mapped_types << min
    mapped_types << max
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
      Types::PDefaultType::DEFAULT
    else
      infer_Object(o)
    end
  end

  # @api private
  def infer_TrueClass(o)
    Types::PBooleanType::DEFAULT
  end

  # @api private
  def infer_FalseClass(o)
    Types::PBooleanType::DEFAULT
  end

  # @api private
  # A Puppet::Parser::Resource, or Puppet::Resource
  #
  def infer_Resource(o)
    # Only Puppet::Resource can have a title that is a symbol :undef, a PResource cannot.
    # A mapping must be made to empty string. A nil value will result in an error later
    title = o.title
    title = '' if :undef == title
    Types::PType.new(Types::PResourceType.new(o.type.to_s.downcase, title))
  end

  # @api private
  def infer_Array(o)
    if o.empty?
      Types::PArrayType::EMPTY
    else
      Types::PArrayType.new(infer_and_reduce_type(o), size_as_type(o))
    end
  end

  # @api private
  def infer_Hash(o)
    if o.empty?
      Types::PHashType::EMPTY
    else
      ktype = infer_and_reduce_type(o.keys)
      etype = infer_and_reduce_type(o.values)
      Types::PHashType.new(ktype, etype, size_as_type(o))
    end
  end

  def size_as_type(collection)
    size = collection.size
    Types::PIntegerType.new(size, size)
  end

  # Common case for everything that intrinsically only has a single type
  def infer_set_Object(o)
    infer(o)
  end

  def infer_set_Array(o)
    if o.empty?
      Types::PArrayType::EMPTY
    else
      Types::PTupleType.new(o.map {|x| infer_set(x) })
    end
  end

  def infer_set_Hash(o)
    if o.empty?
      Types::PHashType::EMPTY
    elsif o.keys.all? {|k| Types::PStringType::NON_EMPTY.instance?(k) }
      Types::PStructType.new(o.each_pair.map { |k,v| Types::PStructElement.new(Types::PStringType.new(nil, [k]), infer_set(v)) })
    else
      ktype = Types::PVariantType.new(o.keys.map {|k| infer_set(k) })
      etype = Types::PVariantType.new(o.values.map {|e| infer_set(e) })
      Types::PHashType.new(unwrap_single_variant(ktype), unwrap_single_variant(etype), size_as_type(o))
    end
  end

  def unwrap_single_variant(possible_variant)
    if possible_variant.is_a?(Types::PVariantType) && possible_variant.types.size == 1
      possible_variant.types[0]
    else
      possible_variant
    end
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
    y = to.nil? ? Float::INFINITY : to
    if x < y
      [x, y]
    else
      [y, x]
    end
  end

  # @api private
  def self.is_kind_of_callable?(t, optional = true)
    t.is_a?(Types::PAnyType) && t.kind_of_callable?(optional)
  end

  def max(a,b)
    a >=b ? a : b
  end

  def min(a,b)
    a <= b ? a : b
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
  def debug_string_Object(t)
    string(t)
  end

  # @api private
  def string_PType(t)
    if t.type.nil?
      'Type'
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

  def string_PAnyType(t)     ; 'Any'; end

  # @api private
  def string_PUndefType(t)     ; 'Undef'   ; end

  # @api private
  def string_PDefaultType(t) ; 'Default' ; end

  # @api private
  def string_PBooleanType(t) ; 'Boolean'; end

  # @api private
  def string_PScalarType(t)  ; 'Scalar'; end

  # @api private
  def string_PDataType(t)    ; 'Data'; end

  # @api private
  def string_PNumericType(t) ; 'Numeric'; end

  # @api private
  def string_PIntegerType(t)
    range = range_array_part(t)
    if range.empty?
      'Integer'
    else
      "Integer[#{range.join(', ')}]"
    end
  end

  # Produces a string from an Integer range type that is used inside other type strings
  # @api private
  def range_array_part(t)
    return [] if t.nil? || t.unbounded?
    [t.from.nil? ? 'default' : t.from , t.to.nil? ? 'default' : t.to ]
  end

  # @api private
  def string_PFloatType(t)
    range = range_array_part(t)
    if range.empty?
      'Float'
    else
      "Float[#{range.join(', ')}]"
    end
  end

  # @api private
  def string_PRegexpType(t)
    t.pattern.nil? ? 'Regexp' : "Regexp[#{t.regexp.inspect}]"
  end

  # @api private
  def string_PStringType(t)
    # skip values in regular output - see debug_string
    range = range_array_part(t.size_type)
    if range.empty?
      'String'
    else
      "String[#{range.join(', ')}]"
    end
  end

  # @api private
  def debug_string_PStringType(t)
    range = range_array_part(t.size_type)
    range_part = range.empty? ? '' : '[' << range.join(' ,') << '], '
    'String[' << range_part << (t.values.map {|s| "'#{s}'" }).join(', ') << ']'
  end

  # @api private
  def string_PEnumType(t)
    return 'Enum' if t.values.empty?
    'Enum[' << t.values.map {|s| "'#{s}'" }.join(', ') << ']'
  end

  # @api private
  def string_PVariantType(t)
    return 'Variant' if t.types.empty?
    'Variant[' << t.types.map {|t2| string(t2) }.join(', ') << ']'
  end

  # @api private
  def string_PTupleType(t)
    range = range_array_part(t.size_type)
    return 'Tuple' if t.types.empty?
    s = 'Tuple[' << t.types.map {|t2| string(t2) }.join(', ')
    unless range.empty?
      s << ', ' << range.join(', ')
    end
    s << ']'
    s
  end

  # @api private
  def string_PCallableType(t)
    # generic
    return 'Callable' if t.param_types.nil?

    if t.param_types.types.empty?
      range = [0, 0]
    else
      range = range_array_part(t.param_types.size_type)
    end
    # translate to string, and skip Unit types
    types = t.param_types.types.map {|t2| string(t2) unless t2.class == Types::PUnitType }.compact

    s = 'Callable[' << types.join(', ')
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
    s << ']'
    s
  end

  # @api private
  def string_PStructType(t)
    return 'Struct' if t.elements.empty?
    'Struct[{' << t.elements.map {|element| string(element) }.join(', ') << '}]'
  end

  def string_PStructElement(t)
    k = t.key_type
    value_optional = t.value_type.assignable?(Types::PUndefType::DEFAULT)
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
    return 'Pattern' if t.patterns.empty?
    'Pattern[' << t.patterns.map {|s| "#{s.regexp.inspect}" }.join(', ') << ']'
  end

  # @api private
  def string_PCollectionType(t)
    range = range_array_part(t.size_type)
    if range.empty?
      'Collection'
    else
      "Collection[#{range.join(', ')}]"
    end
  end

  # @api private
  def string_PUnitType(t)
    'Unit'
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
    'CatalogEntry'
  end

  # @api private
  def string_PHostClassType(t)
    if t.class_name
      "Class[#{t.class_name}]"
    else
      'Class'
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
      'Resource'
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
      'Optional'
    else
      if optional_type.is_a?(Puppet::Pops::Types::PStringType) && optional_type.values.size == 1
        "Optional['#{optional_type.values[0]}']"
      else
        "Optional[#{string(optional_type)}]"
      end
    end
  end

  # Debugging to_s to reduce the amount of output
  def to_s
    '[a TypeCalculator]'
  end

  private

  NAME_SEGMENT_SEPARATOR = '::'.freeze

  def capitalize_segments(s)
    s.split(NAME_SEGMENT_SEPARATOR).map(&:capitalize).join(NAME_SEGMENT_SEPARATOR)
  end

  def common_data?(t1, t2)
    Types::PDataType::DEFAULT.assignable?(t1) && Types::PDataType::DEFAULT.assignable?(t2)
  end

  def common_scalar?(t1, t2)
    Types::PScalarType::DEFAULT.assignable?(t1) && Types::PScalarType::DEFAULT.assignable?(t2)
  end

  def common_numeric?(t1, t2)
    Types::PNumericType::DEFAULT.assignable?(t1) && Types::PNumericType::DEFAULT.assignable?(t2)
  end

end
