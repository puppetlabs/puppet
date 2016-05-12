module Puppet::Pops
module Types
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
# Instance of the classes in the {Types type model} are used to denote a specific type. It is most convenient
# to use the {TypeFactory} when creating instances.
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
# @see TypeFactory for how to create instances of types
# @see TypeParser how to construct a type instance from a String
# @see Types for details about the type model
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
class TypeCalculator

  # @api public
  def self.assignable?(t1, t2)
    singleton.assignable?(t1,t2)
  end

  # Answers, does the given callable accept the arguments given in args (an array or a tuple)
  # @param callable [PCallableType] - the callable
  # @param args [PArrayType, PTupleType] args optionally including a lambda callable at the end
  # @return [Boolan] true if the callable accepts the arguments
  #
  # @api public
  def self.callable?(callable, args)
    singleton.callable?(callable, args)
  end

  # Produces a String representation of the given type.
  # @param t [PAnyType] the type to produce a string form
  # @return [String] the type in string form
  #
  # @api public
  #
  def self.string(t)
    Puppet.deprecation_warning('TypeCalculator.string is deprecated. Use TypeFormatter')
    TypeFormatter.string(t)
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
    Puppet.deprecation_warning('TypeCalculator.debug_string is deprecated. Use TypeFormatter')
    TypeFormatter.debug_string(t)
  end

  # @api public
  def self.enumerable(t)
    Puppet.deprecation_warning('TypeCalculator.enumerable is deprecated. Use iterable')
    singleton.iterable(t)
  end

  # @api public
  def self.iterable(t)
    singleton.iterable(t)
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
    @@infer_visitor ||= Visitor.new(nil, 'infer',0,0)
    @@extract_visitor ||= Visitor.new(nil, 'extract',0,0)
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
    if klazz.is_a?(PRuntimeType)
      klazz = ClassLoader.provide(klazz)
    end

    # data types can not be injected (check again, it is not safe to assume that given RubyRuntime klazz arg was ok)
    return false unless type(klazz).is_a?(PRuntimeType)
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
    t.is_a?(PAnyType) ? t.assignable?(t2) : false
 end

  # Returns an iterable if the t represents something that can be iterated
  def enumerable(t)
    Puppet.deprecation_warning('TypeCalculator.enumerable is deprecated. Use iterable')
    iterable(t)
  end

  # Returns an iterable if the t represents something that can be iterated
  def iterable(t)
    # Create an iterable on the type if possible
    Iterable.on(t)
  end

  # Answers, does the given callable accept the arguments given in args (an array or a tuple)
  #
  def callable?(callable, args)
    callable.is_a?(PAnyType) && callable.callable?(args)
  end

  # Answers if the two given types describe the same type
  def equals(left, right)
    return false unless left.is_a?(PAnyType) && right.is_a?(PAnyType)
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
      type = PIntegerType::DEFAULT
    when c == Float
      type = PFloatType::DEFAULT
    when c == Numeric
      type = PNumericType::DEFAULT
    when c == String
      type = PStringType::DEFAULT
    when c == Regexp
      type = PRegexpType::DEFAULT
    when c == NilClass
      type = PUndefType::DEFAULT
    when c == FalseClass, c == TrueClass
      type = PBooleanType::DEFAULT
    when c == Class
      type = PType::DEFAULT
    when c == Array
      # Assume array of data values
      type = PArrayType::DATA
    when c == Hash
      # Assume hash with scalar keys and data values
      type = PHashType::DATA
   else
      type = PRuntimeType.new(:ruby, c.name)
    end
    type
  end

  # Generalizes value specific types. The generalized type is returned.
  # @api public
  def generalize(o)
    o.is_a?(PAnyType) ? o.generalize : o
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
    when Evaluator::PuppetProc
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
      when Semantic::Version
        infer_set_Version(o)
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
    t.is_a?(PAnyType) ? t.instance?(o) : false
  end

  # Answers if t is a puppet type
  # @api public
  #
  def is_ptype?(t)
    t.is_a?(PAnyType)
  end

  # Answers if t represents the puppet type PUndefType
  # @api public
  #
  def is_pnil?(t)
    t.nil? || t.is_a?(PUndefType)
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
    if t1.is_a?(PUnitType)
      return t2
    elsif t2.is_a?(PUnitType)
      return t1
    end

    # Simple case, one is assignable to the other
    if assignable?(t1, t2)
      return t1
    elsif assignable?(t2, t1)
      return t2
    end

    # when both are arrays, return an array with common element type
    if t1.is_a?(PArrayType) && t2.is_a?(PArrayType)
      return PArrayType.new(common_type(t1.element_type, t2.element_type))
    end

    # when both are hashes, return a hash with common key- and element type
    if t1.is_a?(PHashType) && t2.is_a?(PHashType)
      key_type = common_type(t1.key_type, t2.key_type)
      element_type = common_type(t1.element_type, t2.element_type)
      return PHashType.new(key_type, element_type)
    end

    # when both are host-classes, reduce to PHostClass[] (since one was not assignable to the other)
    if t1.is_a?(PHostClassType) && t2.is_a?(PHostClassType)
      return PHostClassType::DEFAULT
    end

    # when both are resources, reduce to Resource[T] or Resource[] (since one was not assignable to the other)
    if t1.is_a?(PResourceType) && t2.is_a?(PResourceType)
      # only Resource[] unless the type name is the same
      return t1.type_name == t2.type_name ?  PResourceType.new(t1.type_name, nil) : PResourceType::DEFAULT
    end

    # Integers have range, expand the range to the common range
    if t1.is_a?(PIntegerType) && t2.is_a?(PIntegerType)
      return PIntegerType.new([t1.numeric_from, t2.numeric_from].min, [t1.numeric_to, t2.numeric_to].max)
    end

    # Floats have range, expand the range to the common range
    if t1.is_a?(PFloatType) && t2.is_a?(PFloatType)
      return PFloatType.new([t1.numeric_from, t2.numeric_from].min, [t1.numeric_to, t2.numeric_to].max)
    end

    if t1.is_a?(PStringType) && t2.is_a?(PStringType)
      common_size_type = common_type(t1.size_type, t2.size_type) unless t1.size_type.nil? || t2.size_type.nil?
      common_strings = t1.values.empty? || t2.values.empty? ? [] : t1.values | t2.values
      return PStringType.new(common_size_type, common_strings)
    end

    if t1.is_a?(PPatternType) && t2.is_a?(PPatternType)
      return PPatternType.new(t1.patterns | t2.patterns)
    end

    if t1.is_a?(PEnumType) && t2.is_a?(PEnumType)
      # The common type is one that complies with either set
      return PEnumType.new(t1.values | t2.values)
    end

    if t1.is_a?(PVariantType) && t2.is_a?(PVariantType)
      # The common type is one that complies with either set
      return PVariantType.maybe_create(t1.types | t2.types)
    end

    if t1.is_a?(PRegexpType) && t2.is_a?(PRegexpType)
      # if they were identical, the general rule would return a parameterized regexp
      # since they were not, the result is a generic regexp type
      return PPatternType::DEFAULT
    end

    if t1.is_a?(PCallableType) && t2.is_a?(PCallableType)
      # They do not have the same signature, and one is not assignable to the other,
      # what remains is the most general form of Callable
      return PCallableType::DEFAULT
    end

    # Common abstract types, from most specific to most general
    if common_numeric?(t1, t2)
      return PNumericType::DEFAULT
    end

    if common_scalar?(t1, t2)
      return PScalarType::DEFAULT
    end

    if common_data?(t1,t2)
      return PDataType::DEFAULT
    end

    # Meta types Type[Integer] + Type[String] => Type[Data]
    if t1.is_a?(PType) && t2.is_a?(PType)
      return PType.new(common_type(t1.type, t2.type))
    end

    # If both are Runtime types
    if t1.is_a?(PRuntimeType) && t2.is_a?(PRuntimeType)
      if t1.runtime == t2.runtime && t1.runtime_type_name == t2.runtime_type_name
        return t1
      end
      # finding the common super class requires that names are resolved to class
      # NOTE: This only supports runtime type of :ruby
      c1 = ClassLoader.provide_from_type(t1)
      c2 = ClassLoader.provide_from_type(t2)
      if c1 && c2
        c2_superclasses = superclasses(c2)
        superclasses(c1).each do|c1_super|
          c2_superclasses.each do |c2_super|
            if c1_super == c2_super
              return PRuntimeType.new(:ruby, c1_super.name)
            end
          end
        end
      end
    end

    # They better both be Any type, or the wrong thing was asked and nil is returned
    t1.is_a?(PAnyType) && t2.is_a?(PAnyType) ? PAnyType::DEFAULT : nil
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
    Puppet.deprecation_warning('TypeCalculator.string is deprecated. Use TypeFormatter')
    TypeFormatter.singleton.string(t)
  end

  # Produces a debug string representing the type (possibly with more information that the regular string format)
  # @api public
  #
  def debug_string(t)
    Puppet.deprecation_warning('TypeCalculator.debug_string is deprecated. Use TypeFormatter')
    TypeFormatter.singleton.debug_string(t)
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
    PType::new(PRuntimeType.new(:ruby, o.name))
  end

  # @api private
  def infer_Closure(o)
    o.type
  end

  # @api private
  def infer_Iterator(o)
    PIteratorType.new(o.element_type)
  end

  # @api private
  def infer_Function(o)
    o.class.dispatcher.to_type
  end

  # @api private
  def infer_Object(o)
    if o.is_a?(PuppetObject)
      o._ptype
    else
      name = o.class.name
      ir = Loaders.implementation_registry
      type = ir.nil? ? nil : ir.type_for_module(name)
      type.nil? ? PRuntimeType.new(:ruby, name) : type
    end
  end

  # The type of all types is PType
  # @api private
  #
  def infer_PAnyType(o)
    PType.new(o)
  end

  # The type of all types is PType
  # This is the metatype short circuit.
  # @api private
  #
  def infer_PType(o)
    PType.new(o)
  end

  # @api private
  def infer_String(o)
    PStringType.new(size_as_type(o), [o])
  end

  # @api private
  def infer_Float(o)
    PFloatType.new(o, o)
  end

  # @api private
  def infer_Integer(o)
    PIntegerType.new(o, o)
  end

  # @api private
  def infer_Regexp(o)
    PRegexpType.new(o.source)
  end

  # @api private
  def infer_NilClass(o)
    PUndefType::DEFAULT
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
        break PAnyType::DEFAULT
      when :req
        min += 1
      end
      max += 1
      PAnyType::DEFAULT
    end
    mapped_types << min
    mapped_types << max
    TypeFactory.callable(*mapped_types)
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
      PDefaultType::DEFAULT
    when :undef
      PUndefType::DEFAULT
    else
      infer_Object(o)
    end
  end

  # @api private
  def infer_TrueClass(o)
    PBooleanType::DEFAULT
  end

  # @api private
  def infer_FalseClass(o)
    PBooleanType::DEFAULT
  end

  # @api private
  # A Puppet::Parser::Resource, or Puppet::Resource
  #
  def infer_Resource(o)
    # Only Puppet::Resource can have a title that is a symbol :undef, a PResource cannot.
    # A mapping must be made to empty string. A nil value will result in an error later
    title = o.title
    title = '' if :undef == title
    PType.new(PResourceType.new(o.type.to_s, title))
  end

  # @api private
  def infer_Array(o)
    if o.empty?
      PArrayType::EMPTY
    else
      PArrayType.new(infer_and_reduce_type(o), size_as_type(o))
    end
  end

  # @api private
  def infer_Version(o)
    PSemVerType::DEFAULT
  end

  # @api private
  def infer_VersionRange(o)
    PSemVerRangeType::DEFAULT
  end

  # @api private
  def infer_Hash(o)
    if o.empty?
      PHashType::EMPTY
    else
      ktype = infer_and_reduce_type(o.keys)
      etype = infer_and_reduce_type(o.values)
      PHashType.new(ktype, etype, size_as_type(o))
    end
  end

  def size_as_type(collection)
    size = collection.size
    PIntegerType.new(size, size)
  end

  # Common case for everything that intrinsically only has a single type
  def infer_set_Object(o)
    infer(o)
  end

  def infer_set_Array(o)
    if o.empty?
      PArrayType::EMPTY
    else
      PTupleType.new(o.map {|x| infer_set(x) })
    end
  end

  def infer_set_Hash(o)
    if o.empty?
      PHashType::EMPTY
    elsif o.keys.all? {|k| PStringType::NON_EMPTY.instance?(k) }
      PStructType.new(o.each_pair.map { |k,v| PStructElement.new(PStringType.new(size_as_type(k), [k]), infer_set(v)) })
    else
      ktype = PVariantType.maybe_create(o.keys.map {|k| infer_set(k) })
      etype = PVariantType.maybe_create(o.values.map {|e| infer_set(e) })
      PHashType.new(unwrap_single_variant(ktype), unwrap_single_variant(etype), size_as_type(o))
    end
  end

  # @api private
  def infer_set_Version(o)
    PSemVerType.new(Semantic::VersionRange.new(o, o))
  end

  def unwrap_single_variant(possible_variant)
    if possible_variant.is_a?(PVariantType) && possible_variant.types.size == 1
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
    y = to.nil? ? TheInfinity : to
    [x, y]
  end

  # @api private
  def self.is_kind_of_callable?(t, optional = true)
    t.is_a?(PAnyType) && t.kind_of_callable?(optional)
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

  # Debugging to_s to reduce the amount of output
  def to_s
    '[a TypeCalculator]'
  end

  private

  def common_data?(t1, t2)
    PDataType::DEFAULT.assignable?(t1) && PDataType::DEFAULT.assignable?(t2)
  end

  def common_scalar?(t1, t2)
    PScalarType::DEFAULT.assignable?(t1) && PScalarType::DEFAULT.assignable?(t2)
  end

  def common_numeric?(t1, t2)
    PNumericType::DEFAULT.assignable?(t1) && PNumericType::DEFAULT.assignable?(t2)
  end

end
end
end
