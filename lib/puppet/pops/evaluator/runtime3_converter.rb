module Puppet::Pops::Evaluator
# Converts nested 4x supported values to 3x values. This is required because
# resources and other objects do not know about the new type system, and does not support
# regular expressions. Unfortunately this has to be done for array and hash as well.
# A complication is that catalog types needs to be resolved against the scope.
#
# Users should not create instances of this class. Instead the class methods {Runtime3Converter.convert},
# {Runtime3Converter.map_args}, or {Runtime3Converter.instance} should be used
class Runtime3Converter
  MAX_INTEGER =  Puppet::Pops::MAX_INTEGER
  MIN_INTEGER = Puppet::Pops::MIN_INTEGER

  # Converts 4x supported values to a 3x values. Same as calling Runtime3Converter.instance.map_args(...)
  #
  # @param args [Array] Array of values to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Array] The converted values
  #
  def self.map_args(args, scope, undef_value)
    @instance.map_args(args, scope, undef_value)
  end

  # Converts 4x supported values to a 3x values. Same as calling Runtime3Converter.instance.convert(...)
  #
  # @param o [Object]The value to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Object] The converted value
  #
  def self.convert(o, scope, undef_value)
    @instance.convert(o, scope, undef_value)
  end

  # Returns the singleton instance of this class.
  # @return [Runtime3Converter] The singleton instance
  def self.instance
    @instance
  end

  # Converts 4x supported values to a 3x values.
  #
  # @param args [Array] Array of values to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Array] The converted values
  #
  def map_args(args, scope, undef_value)
    args.map {|a| convert(a, scope, undef_value) }
  end

  # Converts a 4x supported value to a 3x value.
  #
  # @param o [Object]The value to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Object] The converted value
  #
  def convert(o, scope, undef_value)
    @convert_visitor.visit_this_2(self, o, scope, undef_value)
  end

  def convert_NilClass(o, scope, undef_value)
    @inner ? :undef : undef_value
  end

  def convert_Integer(o, scope, undef_value)
    return o unless o < MIN_INTEGER || o > MAX_INTEGER
    range_end = o > MAX_INTEGER ? 'max' : 'min'
    raise Puppet::Error, "Use of a Ruby Integer outside of Puppet Integer #{range_end} range, got '#{"0x%x" % o}'"
  end

  def convert_BigDecimal(o, scope, undef_value)
    # transform to same value float value if possible without any rounding error
    f = o.to_f
    return f unless f != o
    raise Puppet::Error, "Use of a Ruby BigDecimal value outside Puppet Float range, got '#{o}'"
  end

  def convert_String(o, scope, undef_value)
    # although wasteful, needed because user code may mutate these strings in Resources
    o.frozen? ? o.dup : o
  end

  def convert_Object(o, scope, undef_value)
    o
  end

  def convert_Array(o, scope, undef_value)
    ic = @inner_converter
    o.map {|x| ic.convert(x, scope, undef_value) }
  end

  def convert_Hash(o, scope, undef_value)
    result = {}
    ic = @inner_converter
    o.each {|k,v| result[ic.convert(k, scope, undef_value)] = ic.convert(v, scope, undef_value) }
    result
  end

  def convert_Iterator(o, scope, undef_value)
    raise Puppet::Error, _('Use of an Iterator is not supported here')
  end

  def convert_Symbol(o, scope, undef_value)
    o == :undef && !@inner ? undef_value : o
  end

  def convert_PAnyType(o, scope, undef_value)
    o
  end

  def convert_PCatalogEntryType(o, scope, undef_value)
    # Since 4x does not support dynamic scoping, all names are absolute and can be
    # used as is (with some check/transformation/mangling between absolute/relative form
    # due to Puppet::Resource's idiosyncratic behavior where some references must be
    # absolute and others cannot be.
    # Thus there is no need to call scope.resolve_type_and_titles to do dynamic lookup.
    t, title = catalog_type_to_split_type_title(o)
    t = Runtime3ResourceSupport.find_resource_type(scope, t) unless t == 'class' || t == 'node'
    Puppet::Resource.new(t, title)
  end

  # Produces an array with [type, title] from a PCatalogEntryType
  # This method is used to produce the arguments for creation of reference resource instances
  # (used when 3x is operating on a resource).
  # Ensures that resources are *not* absolute.
  #
  def catalog_type_to_split_type_title(catalog_type)
    split_type = catalog_type.is_a?(Puppet::Pops::Types::PTypeType) ? catalog_type.type : catalog_type
    case split_type
      when Puppet::Pops::Types::PClassType
        class_name = split_type.class_name
        ['class', class_name.nil? ? nil : class_name.sub(/^::/, '')]
      when Puppet::Pops::Types::PResourceType
        type_name = split_type.type_name
        title = split_type.title
        if type_name =~ /^(::)?[Cc]lass$/
          ['class', title.nil? ? nil : title.sub(/^::/, '')]
        else
          # Ensure that title is '' if nil
          # Resources with absolute name always results in error because tagging does not support leading ::
          [type_name.nil? ? nil : type_name.sub(/^::/, '').downcase, title.nil? ? '' : title]
        end
      else
        #TRANSLATORS 'PClassType' and 'PResourceType' are Puppet types and should not be translated
        raise ArgumentError, _("Cannot split the type %{class_name}, it represents neither a PClassType, nor a PResourceType.") %
            { class_name: catalog_type.class }
    end
  end

  protected

  def initialize(inner = false)
    @inner = inner
    @inner_converter = inner ? self : self.class.new(true)
    @convert_visitor = Puppet::Pops::Visitor.new(self, 'convert', 2, 2)
  end

  @instance = self.new
end

# A Ruby function written for the 3.x API cannot be expected to handle extended data types. This
# converter ensures that they are converted to String format
# @api private
class Runtime3FunctionArgumentConverter < Runtime3Converter

  def convert_Regexp(o, scope, undef_value)
    # Puppet 3x cannot handle parameter values that are regular expressions. Turn into regexp string in
    # source form
    o.inspect
  end

  def convert_Version(o, scope, undef_value)
    # Puppet 3x cannot handle SemVers. Use the string form
    o.to_s
  end

  def convert_VersionRange(o, scope, undef_value)
    # Puppet 3x cannot handle SemVerRanges. Use the string form
    o.to_s
  end

  def convert_Binary(o, scope, undef_value)
    # Puppet 3x cannot handle Binary. Use the string form
    o.to_s
  end

  def convert_Timespan(o, scope, undef_value)
    # Puppet 3x cannot handle Timespans. Use the string form
    o.to_s
  end

  def convert_Timestamp(o, scope, undef_value)
    # Puppet 3x cannot handle Timestamps. Use the string form
    o.to_s
  end

  @instance = self.new
end

end
