module Puppet::Pops
module Evaluator
# AccessOperator handles operator []
# This operator is part of evaluation.
#
class AccessOperator
  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Runtime3Support

  attr_reader :semantic

  # Initialize with AccessExpression to enable reporting issues
  # @param access_expression [Model::AccessExpression] the semantic object being evaluated
  # @return [void]
  #
  def initialize(access_expression)
    @@access_visitor ||= Visitor.new(self, "access", 2, nil)
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
      fail(Issues::BAD_STRING_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
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
      fail(Issues::BAD_STRING_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
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
      fail(Issues::BAD_TYPE_SLICE_ARITY, blamed, :base_type => o, :min=>1, :actual => keys.size)
    end
    assert_keys(keys, o, 1, 1, String, Regexp)
    Types::TypeFactory.regexp(*keys)
  end

  # Evaluates <ary>[] with 1 or 2 arguments. One argument is an index lookup, two arguments is a slice from/to.
  #
  def access_Array(o, scope, keys)
    keys.flatten!
    case keys.size
    when 0
      fail(Issues::BAD_ARRAY_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    when 1
      key = coerce_numeric(keys[0], @semantic.keys[0], scope)
      unless key.is_a?(Integer)
        bad_access_key_type(o, 0, key, Integer)
      end
      o[key]
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
      fail(Issues::BAD_ARRAY_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
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
      fail(Issues::BAD_HASH_SLICE_ARITY, @semantic.left_expr, {:actual => keys.size})
    when 1
      result.pop
    else
      # remove nil elements and return
      result.compact!
      result
    end
  end

  def access_PEnumType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, Float::INFINITY, String)
    Types::TypeFactory.enum(*keys)
  end

  def access_PVariantType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, Float::INFINITY, Types::PAnyType)
    Types::TypeFactory.variant(*keys)
  end

  def access_PSemVerType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, Float::INFINITY, String, Semantic::VersionRange)
    Types::TypeFactory.sem_ver(*keys)
  end

  def access_PTupleType(o, scope, keys)
    keys.flatten!
    if Types::TypeFactory.is_range_parameter?(keys[-2]) && Types::TypeFactory.is_range_parameter?(keys[-1])
      size_type = Types::TypeFactory.range(keys[-2], keys[-1])
      keys = keys[0, keys.size - 2]
    elsif Types::TypeFactory.is_range_parameter?(keys[-1])
      size_type = Types::TypeFactory.range(keys[-1], :default)
      keys = keys[0, keys.size - 1]
    end
    assert_keys(keys, o, 1, Float::INFINITY, Types::PAnyType)
    Types::TypeFactory.tuple(keys, size_type)
  end

  def access_PCallableType(o, scope, keys)
    Types::TypeFactory.callable(*keys)
  end

  def access_PStructType(o, scope, keys)
    assert_keys(keys, o, 1, 1, Hash)
    Types::TypeFactory.struct(keys[0])
  end

  def access_PStringType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      size_t = collection_size_t(0, keys[0])
    when 2
      size_t = collection_size_t(0, keys[0], keys[1])
    else
      fail(Issues::BAD_STRING_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    Types::TypeFactory.string(size_t)
  end

  # Asserts type of each key and calls fail with BAD_TYPE_SPECIFICATION
  # @param keys [Array<Object>] the evaluated keys
  # @param o [Object] evaluated LHS reported as :base_type
  # @param min [Integer] the minimum number of keys (typically 1)
  # @param max [Numeric] the maximum number of keys (use same as min, specific number, or Float::INFINITY)
  # @param allowed_classes [Class] a variable number of classes that each key must be an instance of (any)
  # @api private
  #
  def assert_keys(keys, o, min, max, *allowed_classes)
    size = keys.size
    unless size.between?(min, max || Float::INFINITY)
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, :base_type => o, :min=>1, :max => max, :actual => keys.size)
    end
    keys.each_with_index do |k, i|
      unless allowed_classes.any? {|clazz| k.is_a?(clazz) }
        bad_type_specialization_key_type(o, i, k, *allowed_classes)
      end
    end
  end

  def bad_access_key_type(lhs, key_index, actual, *expected_classes)
    fail(Issues::BAD_SLICE_KEY_TYPE, @semantic.keys[key_index], {
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
      Types::TypeCalculator.generalize(Types::TypeCalculator.infer(actual)).to_s
    end
  end

  def bad_type_specialization_key_type(type, key_index, actual, *expected_classes)
    label_provider = Model::ModelLabelProvider.new()
    expected = expected_classes.map {|c| label_provider.label(c) }.join(' or ')
    fail(Issues::BAD_TYPE_SPECIALIZATION, @semantic.keys[key_index], {
      :type => type,
      :message => "Cannot use #{bad_key_type_name(actual)} where #{expected} is expected"
    })
  end

  def access_PPatternType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 1, Float::INFINITY, String, Regexp, Types::PPatternType, Types::PRegexpType)
    Types::TypeFactory.pattern(*keys)
  end

  def access_POptionalType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      type = keys[0]
      unless type.is_a?(Types::PAnyType)
        if type.is_a?(String)
          type = Types::TypeFactory.string(nil, type)
        else
          fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Optional-Type', :actual => type.class})
        end
      end
      Types::POptionalType.new(type)
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Optional-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PSensitiveType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      type = keys[0]
      unless type.is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Sensitive-Type', :actual => type.class})
      end
      Types::PSensitiveType.new(type)
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Sensitive-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PObjectType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      Types::TypeFactory.object(keys[0])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Object-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PTypeSetType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      Types::TypeFactory.type_set(keys[0])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'TypeSet-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PNotUndefType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 0
      Types::TypeFactory.not_undef
    when 1
      type = keys[0]
      case type
      when String
        type = Types::TypeFactory.string(nil, type)
      when Types::PAnyType
        type = nil if type.class == Types::PAnyType
      else
        fail(Issues::BAD_NOT_UNDEF_SLICE_TYPE, @semantic.keys[0], {:base_type => 'NotUndef-Type', :actual => type.class})
      end
      Types::TypeFactory.not_undef(type)
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'NotUndef-Type', :min => 0, :max => 1, :actual => keys.size})
    end
  end

  def access_PType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      unless keys[0].is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Type-Type', :actual => keys[0].class})
      end
      Types::PType.new(keys[0])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Type-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PIterableType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      unless keys[0].is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Iterable-Type', :actual => keys[0].class})
      end
      Types::PIterableType.new(keys[0])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Iterable-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PIteratorType(o, scope, keys)
    keys.flatten!
    if keys.size == 1
      unless keys[0].is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Iterator-Type', :actual => keys[0].class})
      end
      Types::PIteratorType.new(keys[0])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {:base_type => 'Iterator-Type', :min => 1, :actual => keys.size})
    end
  end

  def access_PRuntimeType(o, scope, keys)
    keys.flatten!
    assert_keys(keys, o, 2, 2, String, String)
    # create runtime type based on runtime and name of class, (not inference of key's type)
    Types::TypeFactory.runtime(*keys)
  end

  def access_PIntegerType(o, scope, keys)
    keys.flatten!
    unless keys.size.between?(1, 2)
      fail(Issues::BAD_INTEGER_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    keys.each_with_index do |x, index|
      fail(Issues::BAD_INTEGER_SLICE_TYPE, @semantic.keys[index],
        {:actual => x.class}) unless (x.is_a?(Integer) || x == :default)
    end
    Types::PIntegerType.new(*keys)
  end

  def access_PFloatType(o, scope, keys)
    keys.flatten!
    unless keys.size.between?(1, 2)
      fail(Issues::BAD_FLOAT_SLICE_ARITY, @semantic, {:actual => keys.size})
    end
    keys.each_with_index do |x, index|
      fail(Issues::BAD_FLOAT_SLICE_TYPE, @semantic.keys[index],
        {:actual => x.class}) unless (x.is_a?(Float) || x.is_a?(Integer) || x == :default)
    end
    from, to = keys
    from = from == :default || from.nil? ? nil : Float(from)
    to = to == :default || to.nil? ? nil : Float(to)
    Types::PFloatType.new(from, to)
  end

  # A Hash can create a new Hash type, one arg sets value type, two args sets key and value type in new type.
  # With 3 or 4 arguments, these are used to create a size constraint.
  # It is not possible to create a collection of Hash types directly.
  #
  def access_PHashType(o, scope, keys)
    keys.flatten!
    if keys.size == 2 && keys[0].is_a?(Integer) && keys[1].is_a?(Integer)
      return Types::PHashType.new(nil, nil, Types::PIntegerType.new(*keys))
    end

    keys[0,2].each_with_index do |k, index|
      unless k.is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[index], {:base_type => 'Hash-Type', :actual => k.class})
      end
    end
    case keys.size
    when 2
      size_t = nil
    when 3
      size_t = keys[2]
      size_t = Types::PIntegerType.new(size_t) unless size_t.is_a?(Types::PIntegerType)
    when 4
      size_t = collection_size_t(2, keys[2], keys[3])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic, {
        :base_type => 'Hash-Type', :min => 2, :max => 4, :actual => keys.size
      })
    end
    Types::PHashType.new(keys[0], keys[1], size_t)
  end

  # CollectionType is parameterized with a range
  def access_PCollectionType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      size_t = collection_size_t(0, keys[0])
    when 2
      size_t = collection_size_t(0, keys[0], keys[1])
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic,
        {:base_type => 'Collection-Type', :min => 1, :max => 2, :actual => keys.size})
    end
    Types::PCollectionType.new(nil, size_t)
  end

  # An Array can create a new Array type. It is not possible to create a collection of Array types.
  #
  def access_PArrayType(o, scope, keys)
    keys.flatten!
    case keys.size
    when 1
      unless keys[0].is_a?(Types::PAnyType)
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Array-Type', :actual => keys[0].class})
      end
      type = keys[0]
      size_t = nil
    when 2
      if keys[0].is_a?(Types::PAnyType)
        size_t = collection_size_t(1, keys[1])
        type = keys[0]
      else
        size_t = collection_size_t(0, keys[0], keys[1])
        type = nil
      end
    when 3
      if keys[0].is_a?(Types::PAnyType)
        size_t = collection_size_t(1, keys[1], keys[2])
        type = keys[0]
      else
        fail(Issues::BAD_TYPE_SLICE_TYPE, @semantic.keys[0], {:base_type => 'Array-Type', :actual => keys[0].class})
      end
    else
      fail(Issues::BAD_TYPE_SLICE_ARITY, @semantic,
        {:base_type => 'Array-Type', :min => 1, :max => 3, :actual => keys.size})
    end
    Types::PArrayType.new(type, size_t)
  end

  # Produces an PIntegerType (range) given one or two keys.
  def collection_size_t(start_index, *keys)
    if keys.size == 1 && keys[0].is_a?(Types::PIntegerType)
      keys[0]
    else
      keys.each_with_index do |x, index|
        fail(Issues::BAD_COLLECTION_SLICE_TYPE, @semantic.keys[start_index + index],
          {:actual => x.class}) unless (x.is_a?(Integer) || x == :default)
      end
      Types::PIntegerType.new(*keys)
    end
  end

  # A Puppet::Resource represents either just a type (no title), or is a fully qualified type/title.
  #
  def access_Resource(o, scope, keys)
    # To access a Puppet::Resource as if it was a PResourceType, simply infer it, and take the type of
    # the parameterized meta type (i.e. Type[Resource[the_resource_type, the_resource_title]])
    t = Types::TypeCalculator.infer(o).type
    # must map "undefined title" from resource to nil
    t.title = nil if t.title == EMPTY_STRING
    access(t, scope, *keys)
  end

  # If a type reference is encountered here, it's an error
  def access_PTypeReferenceType(o, scope, keys)
    fail(Issues::UNKNOWN_RESOURCE_TYPE, @semantic, {:type_name => o.type_string })
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
      fail(Issues::BAD_TYPE_SLICE_ARITY, blamed,
        :base_type => o.to_s, :min => 1, :max => -1, :actual => 0)
    end

    # Must know which concrete resource type to operate on in all cases.
    # It is not allowed to specify the type in an array arg - e.g. Resource[[File, 'foo']]
    # type_name is LHS type_name if set, else the first given arg
    type_name = o.type_name || Types::TypeFormatter.singleton.capitalize_segments(keys.shift)
    type_name = case type_name
    when Types::PResourceType
      type_name.type_name
    when String
      type_name
    else
      # blame given left expression if it defined the type, else the first given key expression
      blame = o.type_name.nil? ? @semantic.keys[0] : @semantic.left_expr
      fail(Issues::ILLEGAL_RESOURCE_SPECIALIZATION, blame, {:actual => bad_key_type_name(type_name)})
    end

    # type name must conform
    if type_name !~ Patterns::CLASSREF_EXT
      fail(Issues::ILLEGAL_CLASSREF, blamed, {:name=>type_name})
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
      optionally_fail(Issues::EMPTY_RESOURCE_SPECIALIZATION, blamed)
      return result_type_array ? [] : nil
    end

    if !o.title.nil?
      # lookup resource and return one or more parameter values
      resource = find_resource(scope, o.type_name, o.title)
      unless resource
        fail(Issues::UNKNOWN_RESOURCE, @semantic, {:type_name => o.type_name, :title => o.title})
      end

      result = keys.map do |k|
        unless is_parameter_of_resource?(scope, resource, k)
          fail(Issues::UNKNOWN_RESOURCE_PARAMETER, @semantic,
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
        fail(Issues::BAD_TYPE_SPECIALIZATION, @semantic.keys[index], {
          :type => o,
          :message => "Cannot use #{bad_key_type_name(t)} where a resource title String is expected"
        })
      end

      Types::PResourceType.new(type_name, t == :no_title ? nil : t)
    end
    # returns single type if request was for a single entity, else an array of types (possibly empty)
    return result_type_array ? result : result.pop
  end

  def access_PHostClassType(o, scope, keys)
    blamed = keys.size == 0 ? @semantic : @semantic.keys[0]
    keys_orig_size = keys.size

    if keys_orig_size == 0
      fail(Issues::BAD_TYPE_SLICE_ARITY, blamed,
        :base_type => o.to_s, :min => 1, :max => -1, :actual => 0)
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
      optionally_fail(Issues::EMPTY_RESOURCE_SPECIALIZATION, blamed)
      return result_type_array ? [] : nil
    end

    if o.class_name.nil?
      # The type argument may be a Resource Type - the Puppet Language allows a reference such as
      # Class[Foo], and this is interpreted as Class[Resource[Foo]] - which is ok as long as the resource
      # does not have a title. This should probably be deprecated.
      #
      result = keys.each_with_index.map do |c, i|
        name = if c.is_a?(Types::PResourceType) && !c.type_name.nil? && c.title.nil?
                 strict_check(c, i)
                 # type_name is already downcase. Don't waste time trying to downcase again
                 c.type_name
               elsif c.is_a?(String)
                 c.downcase
               elsif c.is_a?(Types::PTypeReferenceType)
                 strict_check(c, i)
                 c.type_string.downcase
               else
                 fail(Issues::ILLEGAL_HOSTCLASS_NAME, @semantic.keys[i], {:name => c})
               end

        if name =~ Patterns::NAME
          # Remove leading '::' since all references are global, and 3x runtime does the wrong thing
          Types::PHostClassType.new(name.sub(/^::/, EMPTY_STRING))
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
            fail(Issues::UNKNOWN_RESOURCE_PARAMETER, @semantic,
              {:type_name => 'Class', :title => o.class_name, :param_name=>k})
          end
        end
      else
        fail(Issues::UNKNOWN_RESOURCE, @semantic, {:type_name => 'Class', :title => o.class_name})
      end
    end

    # returns single type as type, else an array of types
    return result_type_array ? result : result.pop
  end

  # PUP-6083 - Using Class[Foo] is deprecated since an arbitrary foo will trigger a "resource not found"
  # @api private
  def strict_check(name, index)
    if Puppet[:strict] != :off
      msg = 'Upper cased class-name in a Class[<class-name>] is deprecated, class-name should be a lowercase string'
      case Puppet[:strict]
      when :error
        fail(Issues::ILLEGAL_HOSTCLASS_NAME, @semantic.keys[index], {:name => name})
      when :warning
        Puppet.warn_once(:deprecation, 'ClassReferenceInUpperCase', msg)
      end
    end
  end

end
end
end
