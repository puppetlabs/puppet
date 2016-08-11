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
    @bld = ''
    append_string(t)
    @bld
  end

  # Produces an string containing newline characters and indentation that represents the given
  # type or literal _t_.
  #
  # @param t [Object] the type or literal to produce a string for
  # @param indent [Integer] the current indentation level
  # @param indent_width [Integer] the number of spaces to use for one indentation
  #
  # @api public
  def indented_string(t, indent = 0, indent_width = 2)
    @indent = indent
    @indent_width = indent_width
    begin
      @bld = ''
      (@indent * @indent_width).times { @bld << ' ' }
      append_string(t)
      @bld << "\n"
      @bld
    ensure
      @indent = nil
      @indent_width = nil
    end
  end

  # @api private
  def ruby_string(ref_ctor, indent, t)
    @ruby = true
    @ref_ctor = ref_ctor
    begin
      indented_string(t, indent)
    ensure
      @ruby = nil
      @ref_ctor = nil
    end
  end


  def append_string(t)
    if @ruby && t.is_a?(PAnyType)
      @ruby = false
      begin
        @bld << @ref_ctor << "('"
        @@string_visitor.visit_this_0(self, t)
        @bld << "')"
      ensure
        @ruby = true
      end
    else
      @@string_visitor.visit_this_0(self, t)
    end
  end

  # Produces a string representing the type where type aliases have been expanded
  # @api public
  #
  def alias_expanded_string(t)
    @expanded = true
    begin
      string(t)
    ensure
      @expanded = false
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
  def string_PAnyType(_)     ; @bld << 'Any'     ; end

  # @api private
  def string_PUndefType(_)   ; @bld << 'Undef'   ; end

  # @api private
  def string_PDefaultType(_) ; @bld << 'Default' ; end

  # @api private
  def string_PBooleanType(_) ; @bld << 'Boolean' ; end

  # @api private
  def string_PScalarType(_)  ; @bld << 'Scalar'  ; end

  # @api private
  def string_PDataType(_)    ; @bld << 'Data'    ; end

  # @api private
  def string_PNumericType(_) ; @bld << 'Numeric' ; end

  # @api private
  def string_PIntegerType(t)
    append_array('Integer', t.unbounded?) { append_elements(range_array_part(t)) }
  end

  # @api private
  def string_PType(t)
    append_array('Type', t.type.nil?) { append_string(t.type) }
  end

  # @api private
  def string_PIterableType(t)
    append_array('Iterable', t.element_type.nil?)  { append_string(t.element_type) }
  end

  # @api private
  def string_PIteratorType(t)
    append_array('Iterator', t.element_type.nil?) { append_string(t.element_type) }
  end

  # @api private
  def string_PFloatType(t)
    append_array('Float', t.unbounded? ) { append_elements(range_array_part(t)) }
  end

  # @api private
  def string_PRegexpType(t)
    append_array('Regexp', t.pattern.nil?) { append_string(t.regexp) }
  end

  # @api private
  def string_PStringType(t)
    range = range_array_part(t.size_type)
    append_array('String', range.empty?) do
      if @debug
        append_elements(range, true)
        append_strings(t.values, true)
        chomp_list
      else
        append_elements(range)
      end
    end
  end

  # @api private
  def string_PEnumType(t)
    append_array('Enum', t.values.empty?) { append_strings(t.values) }
  end

  # @api private
  def string_PVariantType(t)
    append_array('Variant', t.types.empty?) { append_strings(t.types) }
  end

  # @api private
  def string_PSemVerType(t)
    append_array('SemVer', t.ranges.empty?) { append_strings(t.ranges) }
  end

  # @api private
  def string_PSemVerRangeType(t)
    @bld << 'SemVerRange'
  end

  # @api private
  def string_PTupleType(t)
    append_array('Tuple', t.types.empty?) do
      append_strings(t.types, true)
      append_elements(range_array_part(t.size_type), true)
      chomp_list
    end
  end

  # @api private
  def string_PCallableType(t)
    append_array('Callable', t.param_types.nil?) do
      # translate to string, and skip Unit types
      append_strings(t.param_types.types.reject {|t2| t2.class == PUnitType }, true)

      if t.param_types.types.empty?
        append_strings([0, 0], true)
      else
        append_elements(range_array_part(t.param_types.size_type), true)
      end

      # Add block T last (after min, max) if present)
      #
      append_strings([t.block_type], true) unless t.block_type.nil?
      chomp_list
    end
  end

  # @api private
  def string_PStructType(t)
    append_array('Struct', t.elements.empty?) { append_hash(Hash[t.elements.map {|e| struct_element_pair(e) }]) }
  end

  # @api private
  def struct_element_pair(t)
    k = t.key_type
    value_optional = t.value_type.assignable?(PUndefType::DEFAULT)
    if k.is_a?(POptionalType)
      # Output as literal String
      k = t.name if value_optional
    else
      k = value_optional ? PNotUndefType.new(k) : t.name
    end
    [k, t.value_type]
  end

  # @api private
  def string_PPatternType(t)
    append_array('Pattern', t.patterns.empty?) { append_strings(t.patterns.map(&:regexp)) }
  end

  # @api private
  def string_PCollectionType(t)
    range = range_array_part(t.size_type)
    append_array('Collection', range.empty? ) { append_elements(range) }
  end

  # @api private
  def string_PUnitType(_)
    @bld << 'Unit'
  end

  # @api private
  def string_PRuntimeType(t)
    append_array('Runtime') { append_strings([t.runtime, t.name_or_pattern]) }
  end

  # @api private
  def string_PArrayType(t)
    if t.has_empty_range?
      append_array('Array') { append_strings([0, 0]) }
    else
      append_array('Array', t == PArrayType::DATA) do
        append_strings([t.element_type], true)
        append_elements(range_array_part(t.size_type), true)
        chomp_list
      end
    end
  end

  # @api private
  def string_PHashType(t)
    if t.has_empty_range?
      append_array('Hash') { append_strings([0, 0]) }
    else
      append_array('Hash', t == PHashType::DATA) do
        append_strings([t.key_type, t.element_type], true)
        append_elements(range_array_part(t.size_type), true)
        chomp_list
      end
    end
  end

  # @api private
  def string_PCatalogEntryType(_)
    @bld << 'CatalogEntry'
  end

  # @api private
  def string_PHostClassType(t)
    append_array('Class', t.class_name.nil?) { append_elements([t.class_name]) }
  end

  # @api private
  def string_PResourceType(t)
    if t.type_name
      append_array(capitalize_segments(t.type_name), t.title.nil?) { append_string(t.title) }
    else
      @bld << 'Resource'
    end
  end

  # @api private
  def string_PNotUndefType(t)
    contained_type = t.type
    append_array('NotUndef', contained_type.nil? || contained_type.class == PAnyType) do
      if contained_type.is_a?(PStringType) && contained_type.values.size == 1
        append_string(contained_type.values[0])
      else
        append_string(contained_type)
      end
    end
  end

  # @api private
  def string_PAnnotatedMember(m)
    hash = m.i12n_hash
    if hash.size == 1
      string(m.type)
    else
      string(hash)
    end
  end

  # Used when printing names of well known keys in an Object type. Placed in a separate
  # method to allow override.
  # @api private
  def symbolic_key(key)
    @ruby ? "'#{key}'" : key
  end

  # @api private
  def string_PTypeSetType(t)
    append_array('TypeSet') do
      append_hash(t.i12n_hash.each, proc { |k| @bld << symbolic_key(k) }) do |k,v|
        case k
        when KEY_TYPES
          old_ts = @type_set
          @type_set = t
          begin
            append_hash(v, proc { |tk| @bld << symbolic_key(tk) }) do |tk, tv|
              if tv.is_a?(Hash)
                append_object_hash(tv)
              else
                append_string(tv)
              end
            end
          rescue
            @type_set = old_ts
          end
        when KEY_REFERENCES
          append_hash(v, proc { |tk| @bld << symbolic_key(tk) })
        else
          append_string(v)
        end
      end
    end
  end

  # @api private
  def string_PObjectType(t)
    if @expanded
      append_object_hash(t.i12n_hash(@type_set.nil? || !@type_set.defines_type?(t)))
    else
      @bld << (@type_set ? @type_set.name_for(t) : t.label)
    end
  end

  # @api private
  def string_PSensitiveType(t)
    append_array('Sensitive') { append_string(t.type) }
  end

  # @api private
  def string_POptionalType(t)
    optional_type = t.optional_type
    append_array('Optional', optional_type.nil?) do
      if optional_type.is_a?(PStringType) && optional_type.values.size == 1
        append_string(optional_type.values[0])
      else
        append_string(optional_type)
      end
    end
  end

  # @api private
  def string_PTypeAliasType(t)
    expand = @expanded
    if expand && t.self_recursion?
      @guard ||= RecursionGuard.new
      expand = (@guard.add_this(t) & RecursionGuard::SELF_RECURSION_IN_THIS) == 0
    end
    if @type_set.nil?
      @bld << t.name
      if expand
        @bld << ' = '
        append_string(t.resolved_type)
      end
    else
      if expand && @type_set.defines_type?(t)
        append_string(t.resolved_type)
      else
        @bld << @type_set.name_for(t)
      end
    end
  end

  # @api private
  def string_PTypeReferenceType(t)
    append_array('TypeReference') { append_string(t.type_string) }
  end

  # @api private
  def string_Array(t)
    append_array('') { append_strings(t) }
  end

  # @api private
  def string_FalseClass(t)   ; @bld << 'false'       ; end

  # @api private
  def string_Hash(t)
    append_hash(t)
  end

  # @api private
  def string_Module(t)
    append_string(TypeCalculator.singleton.type(t))
  end

  # @api private
  def string_NilClass(t)     ; @bld << (@ruby ? 'nil' : '?') ; end

  # @api private
  def string_Numeric(t)      ; @bld << t.to_s    ; end

  # @api private
  def string_Regexp(t)       ; @bld << t.inspect; end

  # @api private
  def string_String(t)
    # Use single qoute on strings that does not contain single quotes, control characters, or backslashes.
    @bld << StringConverter.singleton.puppet_quote(t)
  end

  # @api private
  def string_Symbol(t)       ; @bld << t.to_s    ; end

  # @api private
  def string_TrueClass(t)    ; @bld << 'true'    ; end

  # @api private
  def string_Version(t)      ; @bld << "'#{t}'"  ; end

  # @api private
  def string_VersionRange(t) ; @bld << "'#{t}'"  ; end

  # Debugging to_s to reduce the amount of output
  def to_s
    '[a TypeFormatter]'
  end

  NAME_SEGMENT_SEPARATOR = '::'.freeze
  STARTS_WITH_ASCII_CAPITAL = /^[A-Z]/

  # Capitalizes each segment in a name separated with the {NAME_SEPARATOR} conditionally. The name
  # will not be subject to capitalization if it already starts with a capital letter. This to avoid
  # that existing camel casing is lost.
  #
  # @param qualified_name [String] the name to capitalize
  # @return [String] the capitalized name
  #
  # @api private
  def capitalize_segments(qualified_name)
    if !qualified_name.is_a?(String) || qualified_name =~ STARTS_WITH_ASCII_CAPITAL
      qualified_name
    else
      segments = qualified_name.split(NAME_SEGMENT_SEPARATOR)
      if segments.size == 1
        qualified_name.capitalize
      else
        segments.each(&:capitalize!)
        segments.join(NAME_SEGMENT_SEPARATOR)
      end
    end
  end

  private

  COMMA_SEP = ', '.freeze

  HASH_ENTRY_OP = ' => '.freeze

  def range_array_part(t)
    t.nil? || t.unbounded? ? EMPTY_ARRAY : [t.from.nil? ? 'default' : t.from.to_s , t.to.nil? ? 'default' : t.to.to_s ]
  end

  def append_object_hash(hash)
    begin
      @expanded = false
      append_array('Object') do
        append_hash(hash, proc { |k| @bld << symbolic_key(k) }) do |k,v|
          case k
          when KEY_ATTRIBUTES, KEY_FUNCTIONS
            # Types might need to be output as type references
            append_hash(v) do |_, fv|
              if fv.is_a?(Hash)
                append_hash(fv, proc { |fak| @bld << symbolic_key(fak) }) do |fak,fav|
                  case fak
                  when KEY_KIND
                    @bld << fav
                  else
                    append_string(fav)
                  end
                end
              else
                append_string(fv)
              end
            end
          when KEY_EQUALITY
            append_array('') { append_strings(v) } if v.is_a?(Array)
          else
            append_string(v)
          end
        end
      end
    ensure
      @expanded = true
    end
  end

  def append_elements(array, to_be_continued = false)
    case array.size
    when 0
    when 1
      @bld << array[0]
      @bld << COMMA_SEP if to_be_continued
    else
      array.each { |elem| @bld << elem << COMMA_SEP }
      chomp_list unless to_be_continued
    end
  end

  def append_strings(array, to_be_continued = false)
    case array.size
    when 0
    when 1
      append_string(array[0])
      @bld << COMMA_SEP if to_be_continued
    else
      array.each do |elem|
        append_string(elem)
        @bld << COMMA_SEP
      end
      chomp_list unless to_be_continued
    end
  end

  def append_array(start, empty = false)
    @bld << start
    unless empty
      @bld << '['
      yield
      @bld << ']'
    end
  end

  def append_hash(hash, key_proc = nil)
    @bld << '{'
    @indent += 1 if @indent
    hash.each do |k, v|
      newline if @indent
      if key_proc.nil?
        append_string(k)
      else
        key_proc.call(k)
      end
      @bld << HASH_ENTRY_OP
      if block_given?
        yield(k, v)
      else
        append_string(v)
      end
      @bld << COMMA_SEP
    end
    chomp_list
    if @indent
      @indent -= 1
      newline
    end
    @bld << '}'
  end

  def newline
    @bld.rstrip!
    @bld << "\n"
    (@indent * @indent_width).times { @bld << ' ' }
  end

  def chomp_list
    @bld.chomp!(COMMA_SEP)
  end

  @singleton = new
  @@string_visitor = Visitor.new(nil, 'string',0,0)
end
end
end
