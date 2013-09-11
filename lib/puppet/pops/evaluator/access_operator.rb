# AccessOperator handles operator []
# This operator is part of evaluation.
#
class Puppet::Pops::Evaluator::AccessOperator
  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  attr_reader :semantic

  # Initialize with AccessExpression to enable reporting issues
  # @param access_expression [Puppet::Pops::Model::AccessExpression] the semantic object being evaluated
  # @return [void]
  #
  def initialize(access_expression)
    @@access_visitor ||= Puppet::Pops::Visitor.new(self, "access", 2, nil)
    @semantic = access_expression
  end

  def access (o, scope, *keys)
    @@access_visitor.visit_this(self, o, scope, keys)
  end

  protected

  def access_Object(o, scope, keys)
    # TODO: Use Issues for better handling
    fail("The [] operator is not applicable to the result of the LHS expression: #{o.class}", semantic.left_expr, scope)
  end

  def access_String(o, scope, keys)
    case keys.size
    when 0
      fail("String supports [] with one or two arguments. Got #{keys.size}", @semantic.left_expr, scope)
    when 1
      o[box_numeric(keys[0], @semantic.keys, scope)]
    when 2
      o[box_numeric(keys[0], @semantic.keys, scope), box_numeric(keys[1], @semantic.keys, scope)]
    else
      fail("String supports [] with one or two arguments. Got #{keys.size}", @semantic.left_expr, scope)
    end
  end

  # Speciaizes the Pattern p into itself p[], one regexp instance p[<regexp string>], or array of regexp instances
  # p[<regexp_string>, <regexp_string>].
  #
  def access_PPatternType(o, scope, keys)
    if keys.size == 0
      return Marshal.load(Marshal.dump(o))
    end
    result = keys.collect {|p| Regexp.new(keys[0]) }
    result.size == 1 ? result.pop : result
  end

  # Evaluates <ary>[] with 1 or 2 arguments. One argument is an index lookup, two arguments is a slice from/to.
  #
  def access_Array(o, scope, keys)
    case keys.size
    when 0
      # What does this mean: <an array>[] ? Is it error, unit, empty array 
      fail("Array supports [] with one or two arguments. Got #{keys.size}", @semantic.left_expr, scope)
    when 1
      # TODO: Objects passed in case of failure are not ideal, it gives all the keys in the model, not the
      # failing key (needs to pass index as well)
      o[box_numeric(keys[0], @semantic.keys, scope)]
    when 2
      # A slice [from, to] with support for -1 to mean start, or end respectively.
      # TODO: Objects passed in case of failure are not ideal, it gives all the keys in the model, not the
      # failing key (needs to pass index as well)
      o[box_numeric(keys[0], @semantic.keys, scope), box_numeric(keys[1], @semantic.keys, scope)]
    else
      # TODO: Use Issues for better handling
      fail("Array supports [] with one or two arguments. Got #{keys.size}", semantic.left_expr, scope)
    end
  end


  # Evaluates <hsh>[] with support for one or more arguments. If more than one argument is used, the result
  # is an array with each lookup.
  #
  def access_Hash(o, scope, keys)
    result = keys.collect {|k| o[k] }
    case result.size
    when 0
      # TODO: Use Issues for better handling
      fail("Hash supports [] with one or more arguments. Got #{keys.size}", semantic.left_expr, scope)
    when 1
      result.pop
    else
      # remove nil elements and return
      result.compact!
      result
    end
  end

  # An integer type provides a way to create an Array of integers from, to (inclusive) (must be given), and an
  # optional step at the 3d position which defaults to 1
  def access_PIntegerType(o, scope, keys)
    if keys.size == 0
      return o
    end

    unless keys.size.between?(2, 3)
      fail("Integer[] only accepts two or three parameters (from, to, step). Got #{keys.size}", @semantic.keys, scope)
    end
    keys.each {|x| fail("Integer[] requires all keys to be integers", @semantic.keys, scope) unless x.is_a?(Numeric) }
    from, to, step = keys
    fail("Integer[] cannot step with increment of 0", @semantic.keys, scope) if step == 0
    step ||= 1

    # Ok, so this is quite bad for very large arrays...
    from.step(to, step).collect {|x| x}
  end

  # A Hash can create a new Hash type, one arg sets value type, two args sets key and value type in new type
  # It is not possible to create a collection of Hash types.
  #
  def access_PHashType(o, scope, keys)
    keys.each do |k|
      unless k.is_a?(Puppet::Pops::Types::PAbstractType)
        fail("Arguments to Hash[] must be types. Got #{k.class}", @semantic.keys, scope)
      end
    end
    case keys.size
    when 0
      Marshal.load(Marshal.dump(o)) # Deep copy
    when 1
      result = Puppet::Pops::Types::PHashType.new()
      result.key_type = Marshal.load(Marshal.dump(o.key_type))
      result.element_type = keys[0]
      result
    when 2
    result = Puppet::Pops::Types::PHashType.new()
    result.key_type = keys[0]
    result.element_type = keys[1]
    result
    else
      # TODO: Use Issues for better handling
      fail("Hash type only accepts one or two type parameters (key, and value type). Got #{keys.size}", @semantic.keys, scope)
    end
  end

  # An Array can create a new Array type. It is not possible to create a collection of Array types.
  #
  def access_PArrayType(o, scope, keys)
    case keys.size
    when 0
      Marshal.load(Marshal.dump(o)) # Deep copy
    when 1
      unless keys[0].is_a?(Puppet::Pops::Types::PAbstractType)
        fail("Argument to Array[] must be a type. Got #{keys[0].class}", @semantic.keys, scope)
      end
      result = Puppet::Pops::Types::PArrayType.new()
      result.element_type = keys[0]
      result
    else
      # TODO: Use Issues for better handling
      fail("Array type only accepts one type parameter (element type). Got #{keys.size}", semantic.right_expr, scope)
    end
  end

  # A Resource can create a new more specific Resource type, and/or an array of resource types
  # If the given type has title set, it can not be specified further.
  # @example
  #   Resource[File]               # => File
  #   Resource[File, 'foo']        # => File[foo]
  #   Resource[File. 'foo', 'bar]  # => [File[foo], File[bar]]
  #   File['foo', 'bar']           # => [File[foo], File[bar]]
  #   File['foo']['bar']           # => ERROR
  #   Resource[File]['foo', 'bar'] # => [File[Foo], File[bar]]
  #   Resource[File, 'foo', 'bar'] # => [File[foo], File[bar]]
  #   Resource[???][]              # => deep copy of the type
  #
  def access_PResourceType(o, scope, keys)
    if keys.size == 0
      return Marshal.load(Marshal.dump(o)) # Deep copy
    end
    unless o.title.nil?
      # TODO: Use Issues for better handling
      fail("Cannot specialize an already specialized resource type", semantic.left_expr, scope)
    end

    # type_name is LHS type_name if set, else the first given arg
    type_name = o.type_name || keys.shift
    type_name = case type_name
    when Puppet::Pops::Types::PResourceType
      type_name.type_name
    when String
      type_name.downcase
    else
      fail("First argument to Resource[] must be a resource type or a string. Got #[type_name.class}")
    end
    keys = [nil] if keys.size < 1 # if there was only a type_name and it was consumed
    result = keys.collect do |t|
      rtype = Puppet::Pops::Types::PResourceType.new()
      rtype.type_name = type_name
      rtype.title = t
      rtype
    end
    # returns single type as type, else an array of types
    result.size == 1 ? result.pop : result
  end

  def access_PHostClassType(o, scope, keys)
    if keys.size == 0
      return Marshal.load(Marshal.dump(o)) # Deep copy
    end
    unless o.class_name.nil?
      # TODO: Use Issues for better handling
      fail("Cannot specialize an already specialized Class type", semantic.left_expr, scope)
    end
    result = keys.collect do |c|
      ctype = Puppet::Pops::Types::PHostClassType.new()
      ctype.class_name = c
      ctype
    end
    # returns single type as type, else an array of types
    result.size == 1 ? result.pop : result
  end
end
