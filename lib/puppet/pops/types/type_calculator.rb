# The TypeCalculator can answer questions about puppet types.
#
# The Puppet type system is primarily based on sub-classing. When asking the type calculator to infer types from Ruby in general, it
# may not provide the wanted answer; it does not for instance take module inclusions and extensions into account. In general the type
# system should be unsurprising for anyone being exposed to the notion of type. The type `Data` may require a bit more explanation; this
# is an abstract type that includes all literal types, as well as Array with an element type compatible with Data, and Hash with key
# compatible with Literal and elements compatible with Data. Expressed differently; Data is what you typically express using JSON (with
# the exception that the Puppet type system also includes Pattern (regular expression) as a literal.
#
# Inference
# ---------
# The `infer(o)` method infers a Puppet type for literal Ruby objects, and for Arrays and Hashes.
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
# PIntegerType, PFloatType, PStringType,... are subtypes of PLiteralType. Even if it is possible to answer certain questions about
# type by looking at the Ruby class of the types this is considered an implementation detail, and such checks should in general
# be performed by the type_calculator which implements the type system semantics.
#
# The PRubyType
# -------------
# The PRubyType corresponds to a Ruby Class, except for the puppet types that are specialized (i.e. PRubyType should not be
# used for Integer, String, etc. since there are specialized types for those).
# When the type calculator deals with PRubyTypes and checks for assignability, it determines the "common ancestor class" of two classes.
# This check is made based on the superclasses of the two classes being compared. In order to perform this, the classes must be present
# (i.e. they are resolved from the string form in the PRubyType to a loaded, instantiated Ruby Class). In general this is not a problem,
# since the question to produce the common super type for two objects means that the classes must be present or there would have been
# no instances present in the first place. If however the classes are not present, the type calculator will fall back and state that
# the two types at least have Object in common.
#
# @see Puppet::Pops::Types::TypeFactory TypeFactory for how to create instances of types
# @see Puppet::Pops::Types::TypeParser TypeParser how to construct a type instance from a String
# @see Puppet::Pops::Types Types for details about the type model
#
# @api public
#
class Puppet::Pops::Types::TypeCalculator

  Types = Puppet::Pops::Types
  TheInfinity = 1.0 / 0.0 # because the Infinity symbol is not defined

  def self.assignable?(t1, t2)
    instance.assignable?(t1,t2)
  end

  def self.string(t)
    instance.string(t)
  end

  def self.infer(o)
    instance.infer(o)
  end

  def self.debug_string(t)
    instance.debug_string(t)
  end

  def self.enumerable(t)
    instance.enumerable(t)
  end

  def self.instance()
    @tc_instance ||= new
  end

  # @api public
  #
  def initialize
    @@assignable_visitor ||= Puppet::Pops::Visitor.new(nil,"assignable",1,1)
    @@infer_visitor ||= Puppet::Pops::Visitor.new(nil,"infer",0,0)
    @@string_visitor ||= Puppet::Pops::Visitor.new(nil,"string",0,0)
    @@inspect_visitor ||= Puppet::Pops::Visitor.new(nil,"debug_string",0,0)
    @@enumerable_visitor ||= Puppet::Pops::Visitor.new(nil,"enumerable",0,0)
    @@extract_visitor ||= Puppet::Pops::Visitor.new(nil,"extract",0,0)

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

    @@assignable_visitor.visit_this_1(self, t, t2)
 end

  # Returns an enumerable if the t represents something that can be iterated
  def enumerable(t)
    @@enumerable_visitor.visit_this_0(self, t)
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
    @@infer_visitor.visit_this_0(self, o)
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
    return t.is_a?(Types::PAbstractType)
  end

  # Answers if t represents the puppet type PNilType
  # @api public
  #
  def is_pnil?(t)
    return t.nil? || t.is_a?(Types::PNilType)
  end

  # Answers, 'What is the common type of t1 and t2?'
  #
  # TODO: The current implementation should be optimized for performance
  #
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
      t.values = t1.values | t2.values
      return t
    end

    if t1.is_a?(Types::PPatternType) && t2.is_a?(Types::PPatternType)
      t = Types::PPatternType.new()
      t.patterns = t1.patterns | t2.patterns
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
      t.types = (t1.types | t2.types).map {|opt_t| opt_t.copy }
      return t
    end

    if t1.is_a?(Types::PRegexpType) && t2.is_a?(Types::PRegexpType)
      # if they were identical, the general rule would return a parameterized regexp
      # since they were not, the result is a generic regexp type
      return Types::PPatternType.new()
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

    # Meta types Type[Integer] + Type[String] => Type[Data]
    if t1.is_a?(Types::PType) && t2.is_a?(Types::PType)
      type = Types::PType.new()
      type.type = common_type(t1.type, t2.type)
      return type
    end

    if t1.is_a?(Types::PRubyType) && t2.is_a?(Types::PRubyType)
      if t1.ruby_class == t2.ruby_class
        return t1
      end
      # finding the common super class requires that names are resolved to class
      c1 = Types::ClassLoader.provide_from_type(t1)
      c2 = Types::ClassLoader.provide_from_type(t2)
      if c1 && c2
        c2_superclasses = superclasses(c2)
        superclasses(c1).each do|c1_super|
          c2_superclasses.each do |c2_super|
            if c1_super == c2_super
              result = Types::PRubyType.new()
              result.ruby_class = c1_super.name
              return result
            end
          end
        end
      end
    end
    # If both are RubyObjects

    if common_pobject?(t1, t2)
      return Types::PObjectType.new()
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
  def infer_Object(o)
    type = Types::PRubyType.new()
    type.ruby_class = o.class.name
    type
  end

  # The type of all types is PType
  # @api private
  #
  def infer_PObjectType(o)
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
  # A Puppet::Parser::Resource, or Puppet::Resource
  #
  def infer_Resource(o)
    t = Types::PResourceType.new()
    t.type_name = o.type.to_s
    t.title = o.title
    t
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
  def assignable_PNilType(t, t2)
    # Only undef/nil is assignable to nil type
    t2.is_a?(Types::PNilType)
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
    return false unless t2.is_a?(Types::PIntegerType)
    trange =  from_to_ordered(t.from, t.to)
    t2range = from_to_ordered(t2.from, t2.to)
    # If t2 min and max are within the range of t
    trange[0] <= t2range[0] && trange[1] >= t2range[1]
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
    # A variant is assignable if t2 is assignable to any of its types
    t.types.any? { |option_t| assignable?(option_t, t2) }
  end

  def assignable_PEnumType(t, t2)
    return true if t == t2 || (t.values.empty? && (t2.is_a?(Types::PStringType) || t2.is_a?(Types::PEnumType)))
    if t2.is_a?(Types::PStringType)
      # if the set of strings are all found in the set of enums
      t2.values.all? { |s| t.values.any? { |e| e == s }}
    else
      false
    end
  end

  # @api private
  def assignable_PStringType(t, t2)
    if t.values.empty?
      # A general string is assignable by any other string, or pattern restricted string
      t2.is_a?(Types::PStringType) || t2.is_a?(Types::PPatternType) || t2.is_a?(Types::PEnumType)
    elsif t2.is_a?(Types::PStringType)
      # A specific string acts as a set of strings - must have exactly the same strings
      Set.new(t.values) == Set.new(t2.values)
    else
      # All others are false, since no other type describes the same set of specific strings
      false
    end
  end

  # @api private
  def assignable_PPatternType(t, t2)
    return true if t == t2
    return false unless t2.is_a? Types::PStringType

    if t2.values.empty?
      # Strings (unknown which ones) cannot all match a pattern, but if there is no pattern it is ok
      # (There should really always be a pattern, but better safe than sorry).
      return t.patterns.empty? ? true : false
    end
    # all strings in String type must match all patterns in Pattern type
    t.patterns.all? do |p|
      re = p.regexp
      t2.values.all? {|v| re.match(v) }
    end
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
  def assignable_PCollectionType(t, t2)
    t2.is_a?(Types::PCollectionType)
  end

  # @api private
  def assignable_PType(t, t2)
    return false unless t2.is_a?(Types::PType)
    assignable?(t.type, t2.type)
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

  def assignable_PCatalogEntryType(t1, t2)
    t2.is_a?(Types::PCatalogEntryType)
  end

  def assignable_PHostClassType(t1, t2)
    return false unless t2.is_a?(Types::PHostClassType)
    # Class = Class[name}, Class[name] != Class
    return true if t1.class_name.nil?
    # Class[name] = Class[name]
    return t1.class_name == t2.class_name
  end

  def assignable_PResourceType(t1, t2)
    return false unless t2.is_a?(Types::PResourceType)
    return true if t1.type_name.nil?
    return false if t1.type_name != t2.type_name
    return true if t1.title.nil?
    return t1.title == t2.title
  end

  # Data is assignable by other Data and by Array[Data] and Hash[Literal, Data]
  # @api private
  def assignable_PDataType(t, t2)
    t2.is_a?(Types::PDataType) || 
    t2.is_a?(Types::PLiteralType) ||
    assignable?(@data_array, t2) ||
    assignable?(@data_hash, t2) ||
    (t2.is_a?(Types::PVariantType) && !t2.types.empty? && t2.types.all? {|t| assignable?(data, t) } )
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
  def string_PObjectType(t)  ; "Object"  ; end

  # @api private
  def string_PNilType(t)     ; 'Undef'   ; end

  # @api private
  def string_PBooleanType(t) ; "Boolean" ; end

  # @api private
  def string_PLiteralType(t) ; "Literal" ; end

  # @api private
  def string_PDataType(t)    ; "Data"    ; end

  # @api private
  def string_PNumericType(t) ; "Numeric" ; end

  # @api private
  def string_PIntegerType(t)
    result = ["Integer"]
    unless t.from.nil? && t.to.nil?
      from = t.from.nil? ? 'default' : t.from
      to = t.to.nil? ? 'default' : t.to
      if from == to
        "Integer[#{from}]"
      else
        "Integer[#{from}, #{to}]"
      end
    else
      "Integer"
    end
  end

  def string_PFloatType(t)
    result = ["Float"]
    unless t.from.nil? && t.to.nil?
      from = t.from.nil? ? 'default' : t.from
      to = t.to.nil? ? 'default' : t.to
      if from == to
        "Float[#{from}]"
      else
        "Float[#{from}, #{to}]"
      end
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
    return "String"
  end

  # @api private
  def debug_string_PStringType(t)
    return "String" # if t.values.empty?
    "String[" << (t.values.map {|s| "'#{s}'" }).join(', ') << ']'
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
  def string_PPatternType(t)
    return "Pattern" if t.patterns.empty?
    "Pattern[" << t.patterns.map {|s| "#{s.regexp.inspect}" }.join(', ') << ']'
  end

  # @api private
  def string_PCollectionType(t)  ; "Collection"  ; end

  # @api private
  def string_PRubyType(t)   ; "Ruby[#{string(t.ruby_class)}]"  ; end

  # @api private
  def string_PArrayType(t)
    "Array[#{string(t.element_type)}]"
  end

  # @api private
  def string_PHashType(t)
    "Hash[#{string(t.key_type)}, #{string(t.element_type)}]"
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
        "#{t.type_name.capitalize}['#{t.title}']"
      else
        "#{t.type_name.capitalize}"
      end
    else
      "Resource"
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
