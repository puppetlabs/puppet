# AccessOperator handles operator []
# This operator is part of evaluation.
#
class Puppet::Pops::Evaluator::AccessOperator
  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  Issues = Puppet::Pops::Issues

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
    @@access_visitor.visit_this_2(self, o, scope, keys)
  end

  protected

  def access_Object(o, scope, keys)
    fail(Issues::OPERATOR_NOT_APPLICABLE, @semantic.left_expr, :operator=>'[]', :left_value => o)
  end

  def access_String(o, scope, keys)
    keys.flatten!
    result = case keys.size
    when 0
      fail(Puppet::Pops::Issues::BAD_STRING_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    when 1
      # Note that Ruby 1.8.7 requires a length of 1 to produce a String
      k1 = coerce_numeric(keys[0], @semantic.keys, scope)
      bad_access_key_type(o, 0, k1, Integer) unless k1.is_a?(Integer)
      k2 = 1
      k1 = k1 < 0 ? o.length + k1 : k1           # abs pos
      # if k1 is outside, a length of 1 always produces an empty string
      if k1 < 0
        ''
      else
        o[ k1, k2 ]
      end
    when 2
      k1 = coerce_numeric(keys[0], @semantic.keys, scope)
      k2 = coerce_numeric(keys[1], @semantic.keys, scope)
      [k1, k2].each_with_index { |k,i| bad_access_key_type(o, i, k, Integer) unless k.is_a?(Integer) }

      k1 = k1 < 0 ? o.length + k1 : k1           # abs pos (negative is count from end)
      k2 = k2 < 0 ? o.length - k1 + k2 + 1 : k2  # abs length (negative k2 is length from pos to end count)
      # if k1 is outside, adjust to first position, and adjust length
      if k1 < 0
        k2 = k2 + k1
        k1 = 0
      end
      o[ k1, k2 ]
    else
      fail(Puppet::Pops::Issues::BAD_STRING_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    end
    # Specified as: an index outside of range, or empty result == empty string
    (result.nil? || result.empty?) ? '' : result
  end

  # Parameterizes a PRegexp Type with a pattern string or r ruby egexp
  #
  def access_PRegexpType(o, scope, keys)
    keys.flatten!
    unless keys.size == 1
      blamed = keys.size == 0 ? @semantic : @semantic.keys[2]
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, blamed, :base_type => o, :min=>1, :actual => keys.size)
    end
    assert_keys(keys, o, 1, 1, String, Regexp)
    Puppet::Pops::Types::TypeFactory.regexp(*keys)
  end

  # Evaluates <ary>[] with 1 or 2 arguments. One argument is an index lookup, two arguments is a slice from/to.
  #
  def access_Array(o, scope, keys)
    keys.flatten!
    case keys.size
    when 0
      fail(Puppet::Pops::Issues::BAD_ARRAY_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    when 1
      k = coerce_numeric(keys[0], @semantic.keys[0], scope)
      unless k.is_a?(Integer)
        bad_access_key_type(o, 0, k, Integer)
      end
      o[k]
    when 2
      # A slice [from, to] with support for -1 to mean start, or end respectively.
      k1 = coerce_numeric(keys[0], @semantic.keys[0], scope)
      k2 = coerce_numeric(keys[1], @semantic.keys[1], scope)

      [k1, k2].each_with_index { |k,i| bad_access_key_type(o, i, k, Integer) unless k.is_a?(Integer) }

      # Help confused Ruby do the right thing (it truncates to the right, but negative index + length can never overlap
      # the available range.
      k1 = k1 < 0 ? o.length + k1 : k1           # abs pos (negative is count from end)
      k2 = k2 < 0 ? o.length - k1 + k2 + 1 : k2  # abs length (negative k2 is length from pos to end count)
      # if k1 is outside, adjust to first position, and adjust length
      if k1 < 0
        k2 = k2 + k1
        k1 = 0
      end
      # Help ruby always return empty array when asking for a sub array
      result = o[ k1, k2 ]
      result.nil? ? [] : result
    else
      fail(Puppet::Pops::Issues::BAD_ARRAY_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    end
  end


  # Evaluates <hsh>[] with support for one or more arguments. If more than one argument is used, the result
  # is an array with each lookup.
  # @note
  #   Does not flatten its keys to enable looking up with a structure
  #
  def access_Hash(o, scope, keys)
    # Look up key in hash, if key is nil or :undef, try alternate form before giving up.
    # This makes :undef and nil "be the same key". (The alternative is to always only write one or the other
    # in all hashes - that is much harder to guarantee since the Hash is a regular Ruby hash.
    #
    result = keys.collect do |k|
      o.fetch(k) do |key|
        case key
        when nil
          o[:undef]
        when :undef
          o[:nil]
        else
          nil
        end
      end
    end
    case result.size
    when 0
      fail(Puppet::Pops::Issues::BAD_HASH_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    when 1
      result.pop
    else
      # remove nil elements and return
      result.compact!
      result
    end
  end

  # Ruby does not have an infinity constant.  TODO: Consider having one constant in Puppet. Now it is in several places.
  INFINITY = 1.0 / 0.0

  def access_PEnumType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, INFINITY, String)
    Puppet::Pops::Types::TypeFactory.enum(*keys)
  end

  def access_PVariantType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, INFINITY, Puppet::Pops::Types::PAbstractType)
    Puppet::Pops::Types::TypeFactory.variant(*keys)
  end

  def access_PStringType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, INFINITY, String)
    Puppet::Pops::Types::TypeFactory.string(*keys)
  end

  # Asserts type of each key and calls fail with BAD_TYPE_SPECIFICATION
  # @param keys [Array<Object>] the evaluated keys
  # @param o [Object] evaluated LHS reported as :base_type
  # @param min [Integer] the minimum number of keys (typically 1)
  # @param max [Numeric] the maximum number of keys (use same as min, specific number, or INFINITY)
  # @param allowed_classes [Class] a variable number of classes that each key must be an instance of (any)
  # @api private
  #
  def assert_keys(keys, o, min, max, *allowed_classes)
    size = keys.size
    unless size.between?(min, max || INFINITY)
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, blamed, :base_type => o, :min=>1, :max => max, :actual => keys.size)
    end
    keys.each_with_index do |k, i|
      unless allowed_classes.any? {|clazz| k.is_a?(clazz) }
        bad_type_specialization_key_type(o, i, k, *allowed_classes)
      end
    end
  end

  def bad_access_key_type(lhs, key_index, actual, *expected_classes)
    fail(Puppet::Pops::Issues::BAD_SLICE_KEY_TYPE, @semantic.keys[key_index], {
      :left_value => lhs,
      :actual => bad_key_type_name(actual),
      :expected_classes => expected_classes
    })
  end

  def bad_key_type_name(actual)
    case actual
    when nil, :undef
      'Undef'
    when :default
      'Default'
    else
      actual.class.name
    end
  end

  def bad_type_specialization_key_type(type, key_index, actual, *expected_classes)
    label_provider = Puppet::Pops::Model::ModelLabelProvider.new()
    expected = expected_classes.map {|c| label_provider.label(c) }.join(' or ')
    fail(Puppet::Pops::Issues::BAD_TYPE_SPECIALIZATION, @semantic.keys[key_index], {
      :type => type,
      :message => "Cannot use #{bad_key_type_name(actual)} where #{expected} is expected"
    })
  end

  def access_PPatternType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, INFINITY, String, Regexp, Puppet::Pops::Types::PPatternType, Puppet::Pops::Types::PRegexpType)
    Puppet::Pops::Types::TypeFactory.pattern(*keys)
  end

  def access_PIntegerType(o, scope, keys)
    keys.flatten!
    unless keys.size.between?(1, 2)
      fail(Puppet::Pops::Issues::BAD_INTEGER_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    keys.each_with_index do |x, index|
      fail(Puppet::Pops::Issues::BAD_INTEGER_SLICE_TYPE, @semantic.keys[index],
        {:actual => x.class}) unless (x.is_a?(Integer) || x == :default)
    end
    ranged_integer = Puppet::Pops::Types::PIntegerType.new()
    from, to = keys
    ranged_integer.from = from == :default ? nil : from
    ranged_integer.to = to == :default ? nil : to
    ranged_integer
  end

  def access_PFloatType(o, scope, keys)
    keys.flatten!
    unless keys.size.between?(1, 2)
      fail(Puppet::Pops::Issues::BAD_FLOAT_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    keys.each_with_index do |x, index|
      fail(Puppet::Pops::Issues::BAD_FLOAT_SLICE_TYPE, @semantic.keys[index],
        {:actual => x.class}) unless (x.is_a?(Float) || x.is_a?(Integer) || x == :default)
    end
    ranged_float = Puppet::Pops::Types::PFloatType.new()
    from, to = keys
    ranged_float.from = from == :default || from.nil? ? nil : Float(from)
    ranged_float.to = to == :default || to.nil? ? nil : Float(to)
    ranged_float
  end

  # A Hash can create a new Hash type, one arg sets value type, two args sets key and value type in new type
  # It is not possible to create a collection of Hash types.
  #
  def access_PHashType(o, scope, keys)
    keys.flatten!
    keys.each_with_index do |k, index|
      unless k.is_a?(Puppet::Pops::Types::PAbstractType)
        fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[index], {:base_type => 'Hash-Type', :actual => k.class})
      end
    end
    case keys.size
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
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Hash-Type', :min => 1, :max => 2, :actual => keys.size})
    end
  end

  # An Array can create a new Array type. It is not possible to create a collection of Array types.
  #
  def access_PArrayType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      unless keys[0].is_a?(Puppet::Pops::Types::PAbstractType)
        fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Array-Type', :actual => keys[0].class})
      end
      result = Puppet::Pops::Types::PArrayType.new()
      result.element_type = keys[0]
      result
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Array-Type', :min => 1, :actual => keys.size})
    end
  end

  # A Resource can create a new more specific Resource type, and/or an array of resource types
  # If the given type has title set, it can not be specified further.
  # @example
  #   Resource[File]               # => File
  #   Resource[File, 'foo']        # => File[foo]
  #   Resource[File. 'foo', 'bar'] # => [File[foo], File[bar]]
  #   File['foo', 'bar']           # => [File[foo], File[bar]]
  #   File['foo']['bar']           # => Value of the 'bar' parameter in the File['foo'] resource
  #   Resource[File]['foo', 'bar'] # => [File[Foo], File[bar]]
  #   Resource[File, 'foo', 'bar'] # => [File[foo], File[bar]]
  #   Resource[File, 'foo']['bar'] # => Value of the 'bar' parameter in the File['foo'] resource
  #
  def access_PResourceType(o, scope, keys)
    keys.flatten!
    if keys.size == 0
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, o,
        :base_type => Puppet::Pops::Types::TypeCalculator.new().string(o), :min => 1, :actual => 0)
    end
    if !o.title.nil?
      # lookup resource and return one or more parameter values
      resource = find_resource(scope, o.type_name, o.title)
      unless resource
        fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE, @semantic, {:type_name => o.type_name, :title => o.title})
      end
      result = keys.map do |k|
        unless is_parameter_of_resource?(scope, resource, k)
          fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE_PARAMETER, @semantic,
            {:type_name => o.type_name, :title => o.title, :param_name=>k})
        end
        get_resource_parameter_value(scope, resource, k)
      end
      return result.size <= 1 ? result.pop : result
    end

    # type_name is LHS type_name if set, else the first given arg
    keys_orig_size = keys.size
    type_name = o.type_name || keys.shift
    type_name = case type_name
    when Puppet::Pops::Types::PResourceType
      type_name.type_name
    when String
      type_name.downcase
    else
      blame = keys_orig_size != keys.size ? @semantic.keys[0] : @semantic.left_expr
      fail(Puppet::Pops::Issues::ILLEGAL_RESOURCE_SPECIALIZATION, blame, {:actual => type_name.class})
    end

    keys = [:no_title] if keys.size < 1 # if there was only a type_name and it was consumed
    result = keys.each_with_index.map do |t, i|
      unless t.is_a?(String) || t == :no_title
        type_to_report = case t
        when nil, :undef
          'Undef'
        when :default
          'Default'
        else
          t.class.name
        end
        index = keys_orig_size != keys.size ? i+1 : i
        fail(Puppet::Pops::Issues::BAD_TYPE_SPECIALIZATION, @semantic.keys[index], {
          :type => o,
          :message => "Cannot use #{type_to_report} where String is expected"
        })
      end

      rtype = Puppet::Pops::Types::PResourceType.new()
      rtype.type_name = type_name
      rtype.title = (t == :no_title ? nil : t)
      rtype
    end
    # returns single type as type, else an array of types
    result.size == 1 ? result.pop : result
  end

  def access_PHostClassType(o, scope, keys)
    keys.flatten!
    if keys.size == 0
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, o,
        :base_type => Puppet::Pops::Types::TypeCalculator.new().string(o), :min => 1, :actual => 0)
    end
    if ! o.class_name.nil?
      # lookup class resource and return one or more parameter values
      resource = find_resource(scope, 'class', o.class_name)
      unless resource
        fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE, @semantic, {:type_name => 'Class', :title => o.class_name})
      end
      result = keys.map do |k|
        unless is_parameter_of_resource?(scope, resource, k)
          fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE_PARAMETER, @semantic,
            {:type_name => 'Class', :title => o.class_name, :param_name=>k})
        end
        get_resource_parameter_value(scope, resource, k)
      end
      return result.size <= 1 ? result.pop : result
      # TODO: if [] is applied to specific class, it should be treated the same as getting
      # a resource parameter. Now it fails the operation
      #
      fail(Puppet::Pops::Issues::ILLEGAL_TYPE_SPECIALIZATION, semantic.left_expr, {:kind => 'Class'})
    end
    # The type argument may be a Resource Type - the Puppet Language allows a reference such as
    # Class[Foo], and this is interpreted as Class[Resource[Foo]] - which is ok as long as the resource
    # does not have a title. This should probably be deprecated.
    #
    result = keys.each_with_index.map do |c, i|
      ctype = Puppet::Pops::Types::PHostClassType.new()
      if c.is_a?(Puppet::Pops::Types::PResourceType) && !c.type_name.nil? && c.title.nil?
        c = c.type_name.downcase
      end
      unless c.is_a?(String)
        fail(Puppet::Pops::Issues::ILLEGAL_HOSTCLASS_NAME, @semantic.keys[i], {:name => c})
      end
      if c !~ Puppet::Pops::Patterns::NAME
        fail(Issues::ILLEGAL_NAME, @semantic.keys[i], {:name=>c})
      end
      ctype.class_name = c
      ctype
    end
    # returns single type as type, else an array of types
    result.size == 1 ? result.pop : result
  end
end
