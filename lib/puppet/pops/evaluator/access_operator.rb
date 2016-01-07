# AccessOperator handles operator []
# This operator is part of evaluation.
#
class Puppet::Pops::Evaluator::AccessOperator
  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  Issues = Puppet::Pops::Issues
  TYPEFACTORY = Puppet::Pops::Types::TypeFactory
  EMPTY_STRING = ''.freeze

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
      k1 = coerce_numeric(keys[0], @semantic.keys[0], scope)
      bad_access_key_type(o, 0, k1, Integer) unless k1.is_a?(Integer)
      k2 = 1
      k1 = k1 < 0 ? o.length + k1 : k1           # abs pos
      # if k1 is outside, a length of 1 always produces an empty string
      if k1 < 0
        EMPTY_STRING
      else
        o[ k1, k2 ]
      end
    when 2
      k1 = coerce_numeric(keys[0], @semantic.keys[0], scope)
      k2 = coerce_numeric(keys[1], @semantic.keys[1], scope)
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
    (result.nil? || result.empty?) ? EMPTY_STRING : result
  end

  # Parameterizes a PRegexp Type with a pattern string or r ruby egexp
  #
  def access_PRegexpType(o, scope, keys)
    keys.flatten!
    unless keys.size == 1
      blamed = keys.size == 0 ? @semantic : @semantic.keys[1]
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
    # Look up key in hash, if key is nil, try alternate form (:undef) before giving up.
    # This is done because the hash may have been produced by 3x logic and may thus contain :undef.
    result = keys.collect do |k|
      o.fetch(k) { |key| key.nil? ? o[:undef] : nil }
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
    assert_keys(keys, o, 1, INFINITY, Puppet::Pops::Types::PAnyType)
    Puppet::Pops::Types::TypeFactory.variant(*keys)
  end

  def access_PTupleType(o, scope, keys)
    keys.flatten!
    if TYPEFACTORY.is_range_parameter?(keys[-2]) && TYPEFACTORY.is_range_parameter?(keys[-1])
      size_type = TYPEFACTORY.range(keys[-2], keys[-1])
      keys = keys[0, keys.size - 2]
    elsif TYPEFACTORY.is_range_parameter?(keys[-1])
      size_type = TYPEFACTORY.range(keys[-1], :default)
      keys = keys[0, keys.size - 1]
    end
    assert_keys(keys, o, 1, INFINITY, Puppet::Pops::Types::PAnyType)
    t = Puppet::Pops::Types::TypeFactory.tuple(*keys)
    # set size type, or nil for default (exactly 1)
    t.size_type = size_type
    t
  end

  def access_PCallableType(o, scope, keys)
    TYPEFACTORY.callable(*keys)
  end

  def access_PStructType(o, scope, keys)
    assert_keys(keys, o, 1, 1, Hash)
    TYPEFACTORY.struct(keys[0])
  end

  def access_PStringType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      size_t = collection_size_t(0, keys[0])
    when 2
      size_t = collection_size_t(0, keys[0], keys[1])
    else
      fail(Puppet::Pops::Issues::BAD_STRING_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    string_t = Puppet::Pops::Types::TypeFactory.string()
    string_t.size_type = size_t
    string_t
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
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, :base_type => o, :min=>1, :max => max, :actual => keys.size)
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
    when nil
      'Undef'
    when :default
      'Default'
    else
      Puppet::Pops::Types::TypeCalculator.generalize!(Puppet::Pops::Types::TypeCalculator.infer(actual)).to_s
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

  def access_POptionalType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      type = keys[0]
      unless type.is_a?(Puppet::Pops::Types::PAnyType) || type.is_a?(String)
        fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Optional-Type', :actual => type.class})
      end
      TYPEFACTORY.optional(type)
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Optional-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PNotUndefType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 0
      TYPEFACTORY.not_undef
    when 1
      type = keys[0]
      case type
      when String
        type = TYPEFACTORY.string(type)
      when Puppet::Pops::Types::PAnyType
        type = nil if type.class == Puppet::Pops::Types::PAnyType
      else
        fail(Puppet::Pops::Issues::BAD_NOT_UNDEF_SLICE_TYPE, @semantic.keys[0], {:base_type => 'NotUndef-Type', :actual => type.class})
      end
      TYPEFACTORY.not_undef(type)
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'NotUndef-Type', :min => 0, :max => 1, :actual => keys.size})
    end
  end

  def access_PType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      unless keys[0].is_a?(Puppet::Pops::Types::PAnyType)
        fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Type-Type', :actual => keys[0].class})
      end
      result = Puppet::Pops::Types::PType.new()
      result.type = keys[0]
      result
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Type-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PRuntimeType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 2, 2, String, String)
    # create runtime type based on runtime and name of class, (not inference of key's type)
    Puppet::Pops::Types::TypeFactory.runtime(*keys)
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
    # NOTE! Do not merge the following line to 4.x. It has the same check in the initialize method
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to

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
    # NOTE! Do not merge the following line to 4.x. It has the same check in the initialize method
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to

    ranged_float.from = from == :default || from.nil? ? nil : Float(from)
    ranged_float.to = to == :default || to.nil? ? nil : Float(to)
    ranged_float
  end

  # A Hash can create a new Hash type, one arg sets value type, two args sets key and value type in new type.
  # With 3 or 4 arguments, these are used to create a size constraint.
  # It is not possible to create a collection of Hash types directly.
  #
  def access_PHashType(o, scope, keys)
    keys.flatten!
    keys[0,2].each_with_index do |k, index|
      unless k.is_a?(Puppet::Pops::Types::PAnyType)
        fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[index], {:base_type => 'Hash-Type', :actual => k.class})
      end
    end
    case keys.size
    when 2
      result = Puppet::Pops::Types::PHashType.new()
      result.key_type = keys[0]
      result.element_type = keys[1]
      result
    when 3
      result = Puppet::Pops::Types::PHashType.new()
      result.key_type = keys[0]
      result.element_type = keys[1]
      size_t = collection_size_t(1, keys[2])
      result
    when 4
      result = Puppet::Pops::Types::PHashType.new()
      result.key_type = keys[0]
      result.element_type = keys[1]
      size_t = collection_size_t(1, keys[2], keys[3])
      result
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic, {
        :base_type => 'Hash-Type', :min => 2, :max => 4, :actual => keys.size
      })
    end
    result.size_type = size_t if size_t
    result
  end

  # CollectionType is parameterized with a range
  def access_PCollectionType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      size_t = collection_size_t(1, keys[0])
    when 2
      size_t = collection_size_t(1, keys[0], keys[1])
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic,
        {:base_type => 'Collection-Type', :min => 1, :max => 2, :actual => keys.size})
    end
    result = Puppet::Pops::Types::PCollectionType.new()
    result.size_type = size_t
    result
  end

  # An Array can create a new Array type. It is not possible to create a collection of Array types.
  #
  def access_PArrayType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      size_t = nil
    when 2
      size_t = collection_size_t(1, keys[1])
    when 3
      size_t = collection_size_t(1, keys[1], keys[2])
    else
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, @semantic,
        {:base_type => 'Array-Type', :min => 1, :max => 3, :actual => keys.size})
    end
    unless keys[0].is_a?(Puppet::Pops::Types::PAnyType)
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Array-Type', :actual => keys[0].class})
    end
    result = Puppet::Pops::Types::PArrayType.new()
    result.element_type = keys[0]
    result.size_type = size_t
    result
  end

  # Produces an PIntegerType (range) given one or two keys.
  def collection_size_t(start_index, *keys)
    if keys.size == 1 && keys[0].is_a?(Puppet::Pops::Types::PIntegerType)
      keys[0].copy
    else
      keys.each_with_index do |x, index|
        fail(Puppet::Pops::Issues::BAD_COLLECTION_SLICE_TYPE, @semantic.keys[start_index + index],
          {:actual => x.class}) unless (x.is_a?(Integer) || x == :default)
      end
      ranged_integer = Puppet::Pops::Types::PIntegerType.new()
      from, to = keys
      # NOTE! Do not merge the following line to 4.x. It has the same check in the initialize method
      raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to

      ranged_integer.from = from == :default ? nil : from
      ranged_integer.to = to == :default ? nil : to
      ranged_integer
    end
  end

  # A Puppet::Resource represents either just a type (no title), or is a fully qualified type/title.
  #
  def access_Resource(o, scope, keys)
    # To access a Puppet::Resource as if it was a PResourceType, simply infer it, and take the type of
    # the parameterized meta type (i.e. Type[Resource[the_resource_type, the_resource_title]])
    t = Puppet::Pops::Types::TypeCalculator.infer(o).type
    # must map "undefined title" from resource to nil
    t.title = nil if t.title == EMPTY_STRING
    access(t, scope, *keys)
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
    blamed = keys.size == 0 ? @semantic : @semantic.keys[0]

    if keys.size == 0
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, blamed,
        :base_type => Puppet::Pops::Types::TypeCalculator.new().string(o), :min => 1, :max => -1, :actual => 0)
    end

    # Must know which concrete resource type to operate on in all cases.
    # It is not allowed to specify the type in an array arg - e.g. Resource[[File, 'foo']]
    # type_name is LHS type_name if set, else the first given arg
    type_name = o.type_name || keys.shift
    type_name = case type_name
    when Puppet::Pops::Types::PResourceType
      type_name.type_name
    when String
      type_name.downcase
    else
      # blame given left expression if it defined the type, else the first given key expression
      blame = o.type_name.nil? ? @semantic.keys[0] : @semantic.left_expr
      fail(Puppet::Pops::Issues::ILLEGAL_RESOURCE_SPECIALIZATION, blame, {:actual => bad_key_type_name(type_name)})
    end

    # type name must conform
    if type_name !~ Puppet::Pops::Patterns::CLASSREF
      fail(Puppet::Pops::Issues::ILLEGAL_CLASSREF, blamed, {:name=>type_name})
    end

    # The result is an array if multiple titles are given, or if titles are specified with an array
    # (possibly multiple arrays, and nested arrays).
    result_type_array = keys.size > 1 || keys[0].is_a?(Array)
    keys_orig_size = keys.size

    keys.flatten!
    keys.compact!

    # If given keys  that were just a mix of empty/nil with empty array as a result.
    # As opposed to calling the function the wrong way (without any arguments), (configurable issue),
    # Return an empty array
    #
    if keys.empty? && keys_orig_size > 0
      optionally_fail(Puppet::Pops::Issues::EMPTY_RESOURCE_SPECIALIZATION, blamed)
      return result_type_array ? [] : nil
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
      return result_type_array ? result : result.pop
    end


    keys = [:no_title] if keys.size < 1 # if there was only a type_name and it was consumed
    result = keys.each_with_index.map do |t, i|
      unless t.is_a?(String) || t == :no_title
        index = keys_orig_size != keys.size ? i+1 : i
        fail(Puppet::Pops::Issues::BAD_TYPE_SPECIALIZATION, @semantic.keys[index], {
          :type => o,
          :message => "Cannot use #{bad_key_type_name(t)} where a resource title String is expected"
        })
      end

      rtype = Puppet::Pops::Types::PResourceType.new()
      rtype.type_name = type_name
      rtype.title = (t == :no_title ? nil : t)
      rtype
    end
    # returns single type if request was for a single entity, else an array of types (possibly empty)
    return result_type_array ? result : result.pop
  end

  def access_PHostClassType(o, scope, keys)
    blamed = keys.size == 0 ? @semantic : @semantic.keys[0]
    keys_orig_size = keys.size

    if keys_orig_size == 0
      fail(Puppet::Pops::Issues::BAD_TYPE_SLICE_ARITY, blamed,
        :base_type => Puppet::Pops::Types::TypeCalculator.new().string(o), :min => 1, :max => -1, :actual => 0)
    end

    # The result is an array if multiple classnames are given, or if classnames are specified with an array
    # (possibly multiple arrays, and nested arrays).
    result_type_array = keys.size > 1 || keys[0].is_a?(Array)

    keys.flatten!
    keys.compact!

    # If given keys  that were just a mix of empty/nil with empty array as a result.
    # As opposed to calling the function the wrong way (without any arguments), (configurable issue),
    # Return an empty array
    #
    if keys.empty? && keys_orig_size > 0
      optionally_fail(Puppet::Pops::Issues::EMPTY_RESOURCE_SPECIALIZATION, blamed)
      return result_type_array ? [] : nil
    end

    if o.class_name.nil?
      # The type argument may be a Resource Type - the Puppet Language allows a reference such as
      # Class[Foo], and this is interpreted as Class[Resource[Foo]] - which is ok as long as the resource
      # does not have a title. This should probably be deprecated.
      #
      result = keys.each_with_index.map do |c, i|
        name = if c.is_a?(Puppet::Pops::Types::PResourceType) && !c.type_name.nil? && c.title.nil?
                 # type_name is already downcase. Don't waste time trying to downcase again
                 c.type_name
               elsif c.is_a?(String)
                 c.downcase
               else
                 fail(Puppet::Pops::Issues::ILLEGAL_HOSTCLASS_NAME, @semantic.keys[i], {:name => c})
               end

        if name =~ Puppet::Pops::Patterns::NAME
          ctype = Puppet::Pops::Types::PHostClassType.new()
          # Remove leading '::' since all references are global, and 3x runtime does the wrong thing
          ctype.class_name = name.sub(/^::/, EMPTY_STRING)
          ctype
        else
          fail(Issues::ILLEGAL_NAME, @semantic.keys[i], {:name=>c})
        end
      end
    else
      # lookup class resource and return one or more parameter values
      resource = find_resource(scope, 'class', o.class_name)
      if resource
        result = keys.map do |k|
          if is_parameter_of_resource?(scope, resource, k)
            get_resource_parameter_value(scope, resource, k)
          else
            fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE_PARAMETER, @semantic,
              {:type_name => 'Class', :title => o.class_name, :param_name=>k})
          end
        end
      else
        fail(Puppet::Pops::Issues::UNKNOWN_RESOURCE, @semantic, {:type_name => 'Class', :title => o.class_name})
      end
    end

    # returns single type as type, else an array of types
    return result_type_array ? result : result.pop
  end
end
