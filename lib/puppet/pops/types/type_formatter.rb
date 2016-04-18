module Puppet::Pops
module Types
# String
# ------
# Creates a string representation of a type.
#
# @api public
#
class TypeFormatter
  # Produces a String representation of the given type.
  # @param t [PAnyType] the type to produce a string form
  # @return [String] the type in string form
  #
  # @api public
  #
  def self.string(t)
    @singleton.string(t)
  end

  # @return [TypeCalculator] the singleton instance
  #
  # @api private
  def self.singleton
    @singleton
  end

  # Produces a string representing the type
  # @api public
  #
  def string(t)
    @@string_visitor.visit_this_0(self, t)
  end

  # Produces a string representing the type where type aliases have been expanded
  # @api public
  #
  def alias_expanded_string(t)
    @expand_aliases = true
    begin
      string(t)
    ensure
      @expand_aliases = false
    end
  end

  # Produces a debug string representing the type (possibly with more information that the regular string format)
  # @api public
  #
  def debug_string(t)
    @debug = true
    begin
      string(t)
    ensure
      @debug = false
    end
  end

  # @api private
  def string_Module(t)
    string(TypeCalculator.singleton.type(t))
  end

  # @api private
  def string_NilClass(t)     ; '?'       ; end

  # @api private
  def string_String(t)       ; t.inspect ; end

  # @api private
  def string_Symbol(t)       ; t.to_s    ; end

  # @api private
  def string_PAnyType(t)     ; 'Any'     ; end

  # @api private
  def string_PUndefType(t)   ; 'Undef'   ; end

  # @api private
  def string_PDefaultType(t) ; 'Default' ; end

  # @api private
  def string_PBooleanType(t) ; 'Boolean' ; end

  # @api private
  def string_PScalarType(t)  ; 'Scalar'  ; end

  # @api private
  def string_PDataType(t)    ; 'Data'    ; end

  # @api private
  def string_PNumericType(t) ; 'Numeric' ; end

  # @api private
  def string_PIntegerType(t)
    append_array('Integer', range_array_part(t))
  end

  # @api private
  def string_PType(t)
    append_array('Type', t.type.nil? ? EMPTY_ARRAY : [string(t.type)])
  end

  # @api private
  def string_PIterableType(t)
    append_array('Iterable', t.element_type.nil? ? EMPTY_ARRAY : [string(t.element_type)])
  end

  # @api private
  def string_PIteratorType(t)
    append_array('Iterator', t.element_type.nil? ? EMPTY_ARRAY : [string(t.element_type)])
  end

  # @api private
  def string_PFloatType(t)
    append_array('Float', range_array_part(t))
  end

  # @api private
  def string_PRegexpType(t)
    append_array('Regexp', t.pattern.nil? ? EMPTY_ARRAY : [t.regexp.inspect])
  end

  # @api private
  def string_PStringType(t)
    elements = range_array_part(t.size_type)
    elements += t.values.map {|s| "'#{s}'" } if @debug
    append_array('String', elements)
  end

  # @api private
  def string_PEnumType(t)
    append_array('Enum', t.values.map {|s| "'#{s}'" })
  end

  # @api private
  def string_PVariantType(t)
    append_array('Variant', t.types.map {|t2| string(t2) })
  end

  # @api private
  def string_PTupleType(t)
    type_strings = t.types.map {|t2| string(t2) }
    type_strings += range_array_part(t.size_type) unless type_strings.empty?
    append_array('Tuple', type_strings)
  end

  # @api private
  def string_PCallableType(t)
    elements = EMPTY_ARRAY
    unless t.param_types.nil?
      # translate to string, and skip Unit types
      elements = t.param_types.types.map {|t2| string(t2) unless t2.class == PUnitType }.compact

      if t.param_types.types.empty?
        elements += ['0', '0']
      else
        elements += range_array_part(t.param_types.size_type)
      end

      # Add block T last (after min, max) if present)
      #
      unless t.block_type.nil?
        elements << string(t.block_type)
      end
    end
    append_array('Callable', elements)
  end

  # @api private
  def string_PStructType(t)
    args = t.elements.empty? ? EMPTY_ARRAY : [append_hash('', t.elements.map {|e| hash_entry_PStructElement(e)})]
    append_array('Struct', args)
  end

  # @api private
  def hash_entry_PStructElement(t)
    k = t.key_type
    value_optional = t.value_type.assignable?(PUndefType::DEFAULT)
    key_string =
      if k.is_a?(POptionalType)
        # Output as literal String
        value_optional ? "'#{t.name}'" : string(k)
      else
        value_optional ? "NotUndef['#{t.name}']" : "'#{t.name}'"
      end
    [key_string, string(t.value_type)]
  end

  # @api private
  def string_PPatternType(t)
    append_array('Pattern', t.patterns.map {|s| "#{s.regexp.inspect}" })
  end

  # @api private
  def string_PCollectionType(t)
    append_array('Collection', range_array_part(t.size_type))
  end

  # @api private
  def string_PUnitType(t)
    'Unit'
  end

  # @api private
  def string_PRuntimeType(t)
    append_array('Runtime', [string(t.runtime), string(t.runtime_type_name)])
  end

  def is_empty_range?(from, to)
    from == 0 && to == 0
  end

  # @api private
  def string_PArrayType(t)
    if t.has_empty_range?
      append_array('Array', ['0', '0'])
    else
      append_array('Array', t == PArrayType::DATA ? EMPTY_ARRAY : [string(t.element_type)] + range_array_part(t.size_type))
    end
  end

  # @api private
  def string_PHashType(t)
    if t.has_empty_range?
      append_array('Hash', ['0', '0'])
    else
      append_array('Hash', t == PHashType::DATA ? EMPTY_ARRAY : [string(t.key_type), string(t.element_type)] + range_array_part(t.size_type))
    end
  end

  # @api private
  def string_PCatalogEntryType(t)
    'CatalogEntry'
  end

  # @api private
  def string_PHostClassType(t)
    append_array('Class', t.class_name.nil? ? EMPTY_ARRAY : [t.class_name])
  end

  # @api private
  def string_PResourceType(t)
    if t.type_name
      append_array(capitalize_segments(t.type_name), t.title.nil? ? EMPTY_ARRAY : ["'#{t.title}'"])
    else
      'Resource'
    end
  end

  # @api private
  def string_PNotUndefType(t)
    contained_type = t.type
    if contained_type.nil? || contained_type.class == PAnyType
      args = EMPTY_ARRAY
    else
      if contained_type.is_a?(PStringType) && contained_type.values.size == 1
        args = [ "'#{contained_type.values[0]}'" ]
      else
        args = [ string(contained_type) ]
      end
    end
    append_array('NotUndef', args)
  end

  # @api private
  def string_POptionalType(t)
    optional_type = t.optional_type
    if optional_type.nil?
      args = EMPTY_ARRAY
    else
      if optional_type.is_a?(PStringType) && optional_type.values.size == 1
        args = [ "'#{optional_type.values[0]}'" ]
      else
        args = [ string(optional_type) ]
      end
    end
    append_array('Optional', args)
  end

  # @api private
  def string_PTypeAliasType(t)
    expand = @expand_aliases
    if expand && t.self_recursion?
      @guard ||= RecursionGuard.new
      expand = (@guard.add_this(t) & RecursionGuard::SELF_RECURSION_IN_THIS) == 0
    end
    expand ? "#{t.name} = #{string(t.resolved_type)}" : t.name
  end

  # @api private
  def string_PTypeReferenceType(t)
    if t.parameters.empty?
      t.name
    else
      append_array(t.name.clone, t.parameters.map {|p| string(p) })
    end
  end

  # Debugging to_s to reduce the amount of output
  def to_s
    '[a TypeFormatter]'
  end

  private

  NAME_SEGMENT_SEPARATOR = '::'.freeze

  COMMA_SEP = ', '.freeze

  HASH_ENTRY_OP = ' => '.freeze

  def range_array_part(t)
    t.nil? || t.unbounded? ? EMPTY_ARRAY : [t.from.nil? ? 'default' : t.from.to_s , t.to.nil? ? 'default' : t.to.to_s ]
  end

  def append_array(bld, array)
    case array.size
    when 0
    when 1
      bld << '[' << array[0] << ']'
    else
      bld << '['
      array.each { |elem| bld << elem << COMMA_SEP }
      bld.chomp!(COMMA_SEP)
      bld << ']'
    end
    bld
  end

  def append_hash(bld, hash_entries)
    bld << '{'
    hash_entries.each { |k, v| bld << k  << HASH_ENTRY_OP << v << COMMA_SEP }
    bld.chomp!(COMMA_SEP)
    bld << '}'
    bld
  end

  def capitalize_segments(s)
    s.split(NAME_SEGMENT_SEPARATOR).map(&:capitalize).join(NAME_SEGMENT_SEPARATOR)
  end

  @singleton = new
  @@string_visitor = Visitor.new(nil, 'string',0,0)
end
end
end
