module Puppet::Pops::Evaluator
# Converts nested 4x supported values to 3x values. This is required because
# resources and other objects do not know about the new type system, and does not support
# regular expressions. Unfortunately this has to be done for array and hash as well.
# A complication is that catalog types needs to be resolved against the scope.
#
# Users should not create instances of this class. Instead the class methods {Runtime3Converter.convert},
# {Runtime3Converter.map_args}, or {Runtime3Converter.instance} should be used
class Runtime3Converter
  # Converts 4x supported values to a 3x values. Same as calling Runtime3Converter.instance.map_args(...)
  #
  # @param args [Array] Array of values to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Array] The converted values
  #
  def self.map_args(args, scope, undef_value)
    @@instance.map_args(args, scope, undef_value)
  end

  # Converts 4x supported values to a 3x values. Same as calling Runtime3Converter.instance.convert(...)
  #
  # @param o [Object]The value to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Object] The converted value
  #
  def self.convert(o, scope, undef_value)
    @@instance.convert(o, scope, undef_value)
  end

  # Returns the singleton instance of this class.
  # @return [Runtime3Converter] The singleton instance
  def self.instance
    @@instance
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
    undef_value
  end

  def convert2_NilClass(o, scope, undef_value)
    :undef
  end

  def convert_String(o, scope, undef_value)
    # although wasteful, needed because user code may mutate these strings in Resources
    o.frozen? ? o.dup : o
  end
  alias convert2_String :convert_String

  def convert_Object(o, scope, undef_value)
    o
  end
  alias :convert2_Object :convert_Object

  def convert_Array(o, scope, undef_value)
    o.map {|x| convert2(x, scope, undef_value) }
  end
  alias :convert2_Array :convert_Array

  def convert_Hash(o, scope, undef_value)
    result = {}
    o.each {|k,v| result[convert2(k, scope, undef_value)] = convert2(v, scope, undef_value) }
    result
  end
  alias :convert2_Hash :convert_Hash

  def convert_Iterator(o, scope, undef_value)
    raise Puppet::Error, 'Use of an Iterator is not supported here'
  end
  alias :convert2_Iterator :convert_Iterator

  def convert_Regexp(o, scope, undef_value)
    # Puppet 3x cannot handle parameter values that are reqular expressions. Turn into regexp string in
    # source form
    o.inspect
  end
  alias :convert2_Regexp :convert_Regexp

  def convert_SemVer(o, scope, undef_value)
    # Puppet 3x cannot handle SemVers. Use the string form
    o.to_s
  end
  alias :convert2_SemVer :convert_SemVer

  def convert_SemVerRange(o, scope, undef_value)
    # Puppet 3x cannot handle SemVerRanges. Use the string form
    o.to_s
  end
  alias :convert2_SemVerRange :convert_SemVerRange

  def convert_Symbol(o, scope, undef_value)
    case o
      # Support :undef since it may come from a 3x structure
      when :undef
        undef_value  # 3x wants undef as either empty string or :undef
      else
        o   # :default, and all others are verbatim since they are new in future evaluator
    end
  end

  # The :undef symbol should not be converted when nested in arrays or hashes
  def convert2_Symbol(o, scope, undef_value)
    o
  end

  def convert_PAnyType(o, scope, undef_value)
    o
  end
  alias :convert2_PAnyType :convert_PAnyType

  def convert_PCatalogEntryType(o, scope, undef_value)
    # Since 4x does not support dynamic scoping, all names are absolute and can be
    # used as is (with some check/transformation/mangling between absolute/relative form
    # due to Puppet::Resource's idiosyncratic behavior where some references must be
    # absolute and others cannot be.
    # Thus there is no need to call scope.resolve_type_and_titles to do dynamic lookup.

    Puppet::Resource.new(*catalog_type_to_split_type_title(o))
  end
  alias :convert2_PCatalogEntryType :convert_PCatalogEntryType

  # Produces an array with [type, title] from a PCatalogEntryType
  # This method is used to produce the arguments for creation of reference resource instances
  # (used when 3x is operating on a resource).
  # Ensures that resources are *not* absolute.
  #
  def catalog_type_to_split_type_title(catalog_type)
    split_type = catalog_type.is_a?(Puppet::Pops::Types::PType) ? catalog_type.type : catalog_type
    case split_type
      when Puppet::Pops::Types::PHostClassType
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
        raise ArgumentError, "Cannot split the type #{catalog_type.class}, it represents neither a PHostClassType, nor a PResourceType."
    end
  end

  private

  def initialize
    @convert_visitor  = Puppet::Pops::Visitor.new(self, 'convert', 2, 2)
    @convert2_visitor = Puppet::Pops::Visitor.new(self, 'convert2', 2, 2)
  end

  @@instance = self.new

  # Converts a nested 4x supported value to a 3x value.
  #
  # @param o [Object]The value to convert
  # @param scope [Puppet::Parser::Scope] The scope to use when converting
  # @param undef_value [Object] The value that nil is converted to
  # @return [Object] The converted value
  #
  def convert2(o, scope, undef_value)
    @convert2_visitor.visit_this_2(self, o, scope, undef_value)
  end
end
end
