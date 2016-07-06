module Puppet::Pops
module Types

# Converts Puppet runtime objects to String under the control of a Format.
# Use from Puppet Language is via the function `new`.
#
# @api private
#
class StringConverter

  # @api private
  class FormatError < ArgumentError
    def initialize(type_string, actual, expected)
      super "Illegal format '#{actual}' specified for value of #{type_string} type - expected one of the characters '#{expected}'"
    end
  end

  class Indentation
    attr_reader :level
    attr_reader :first
    attr_reader :is_indenting
    alias :first? :first
    alias :is_indenting? :is_indenting

    def initialize(level, first, is_indenting)
      @level = level
      @first = first
      @is_indenting = is_indenting
    end

    def subsequent
      first? ? self.class.new(level, false, @is_indenting) : self
    end

    def indenting(indenting_flag)
      self.class.new(level, first?, indenting_flag)
    end

    def increase(indenting_flag = false)
      self.class.new(level + 1, true, indenting_flag)
    end

    def breaks?
      is_indenting? && level > 0 && ! first?
    end

    def padding
      return ' ' * 2 * level
    end
  end

  # Format represents one format specification that is textually represented by %<flags><width>.<precision><format>
  # Format parses and makes the individual parts available when an instance is created.
  # 
  # @api private
  #
  class Format
    # Boolean, alternate form (varies in meaning)
    attr_reader :alt
    alias :alt? :alt

    # Nil or Integer with width of field > 0
    attr_reader :width
    # Nil or Integer precisions
    attr_reader :prec
    # One char symbol denoting the format
    attr_reader :format
    # Symbol, :space, :plus, :ignore
    attr_reader :plus
    # Boolean, left adjust in given width or not
    attr_reader :left
    # Boolean left_pad with zero instead of space
    attr_reader :zero_pad
    # Delimiters for containers, a "left" char representing the pair <[{(
    attr_reader :delimiters

    # Map of type to format for elements contained in an object this format applies to
    attr_accessor :container_string_formats

    # Separator string inserted between elements in a container
    attr_accessor :separator

    # Separator string inserted between sub elements in a container
    attr_accessor :separator2

    attr_reader :orig_fmt

    FMT_PATTERN = /^%([\s\+\-#0\[\{<\(\|]*)([1-9][0-9]*)?(?:\.([0-9]+))?([a-zA-Z])/
    DELIMITERS  = [ '[', '{', '(', '<', '|',]
    DELIMITER_MAP = {
      '[' => ['[', ']'],
      '{' => ['{', '}'],
      '(' => ['(', ')'],
      '<' => ['<', '>'],
      '|' => ['|', '|'],
      :space => ['', '']
    }.freeze

    def initialize(fmt)
      @orig_fmt = fmt
      match = FMT_PATTERN.match(fmt)
      unless match
        raise ArgumentError, "The format '#{fmt}' is not a valid format on the form '%<flags><width>.<prec><format>'"
      end

      @format = match[4]
      unless @format.is_a?(String) && @format.length == 1
        raise ArgumentError, "The format must be a one letter format specifier, got '#{@format}'"
      end
      @format = @format.to_sym
      flags  = match[1].split('') || []
      unless flags.uniq.size == flags.size
        raise ArgumentError, "The same flag can only be used once, got '#{fmt}'"
      end
      @left  = flags.include?('-')
      @alt   = flags.include?('#')
      @plus  = (flags.include?(' ') ? :space : (flags.include?('+') ? :plus : :ignore))
      @zero_pad = flags.include?('0')

      @delimiters = nil
      DELIMITERS.each do |d|
        next unless flags.include?(d)
          if !@delimiters.nil?
            raise ArgumentError, "Only one of the delimiters [ { ( < | can be given in the format flags, got '#{fmt}'"
          end
          @delimiters = d
      end

      @width = match[2] ? match[2].to_i : nil
      @prec  = match[3] ? match[3].to_i : nil
    end

    # Merges one format into this and returns a new `Format`. The `other` format overrides this.
    # @param [Format] other
    # @returns [Format] a merged format
    #
    def merge(other)
      result = Format.new(other.orig_fmt)
      result.separator = other.separator || separator
      result.separator2 = other.separator2 || separator2
      result.container_string_formats = Format.merge_string_formats(container_string_formats, other.container_string_formats)
      result
    end

    # Merges two formats where the `higher` format overrides the `lower`. Produces a new `Format`
    # @param [Format] lower
    # @param [Format] higher
    # @returns [Format] the merged result
    #
    def self.merge(lower, higher)
      unless lower && higher
        return lower || higher
      end
      lower.merge(higher)
    end

    # Merges a type => format association and returns a new merged and sorted association.
    # @param [Format] lower
    # @param [Format] higher
    # @returns [Hash] the merged type => format result
    #
    def self.merge_string_formats(lower, higher)
      unless lower && higher
        return lower || higher
      end
      merged = (lower.keys + higher.keys).uniq.map do |k|
        [k, merge(lower[k], higher[k])]
      end
      sort_formats(merged)
    end

    # Sorts format based on generality of types - most specific types before general
    #
    def self.sort_formats(format_map)
      format_map = format_map.sort do |(a,_),(b,_)| 
        ab = b.assignable?(a)
        ba = a.assignable?(b)
        if a == b
          0
        elsif ab && !ba
          -1
        elsif !ab && ba
          1
        else
          # arbitrary order if disjunct (based on name of type)
          rank_a = type_rank(a)
          rank_b = type_rank(b)
          if rank_a == 0 || rank_b == 0
            a.to_s <=> b.to_s
          else
            rank_a <=> rank_b
          end
        end
      end
      Hash[format_map]
    end

    # Ranks type on specificity where it matters
    # lower number means more specific
    def self.type_rank(t)
      case t
      when PStructType
        1
      when PHashType
        2
      when PTupleType
        3
      when PArrayType
        4
      when PPatternType
        10
      when PEnumType
        11
      when PStringType
        12
      else
        0
      end
    end
    # Returns an array with a delimiter pair derived from the format.
    # If format does not contain a delimiter specification the given default is returned
    # 
    # @param [Array<String>] the default delimiters
    # @returns [Array<String>] a tuple with left, right delimiters
    #
    def delimiter_pair(default = StringConverter::DEFAULT_ARRAY_DELIMITERS)
      DELIMITER_MAP[ @delimiters || @plus ] || default
    end

    def to_s
      "%#{@flags}#{@width}.#{@prec}#{@format}"
    end
  end

  # @api public
  def self.convert(value, string_formats = :default)
    singleton.convert(value, string_formats)
  end

  # @return [TypeConverter] the singleton instance
  #
  # @api public
  def self.singleton
    @tconv_instance ||= new
  end

  # @api private
  #
  def initialize
    @@string_visitor   ||= Visitor.new(self, "string", 3, 3)
  end

  DEFAULT_INDENTATION = Indentation.new(0, true, false).freeze

  # format used by default for values in a container
  # (basically strings are quoted since they may contain a ','))
  #
  DEFAULT_CONTAINER_FORMATS = {
    PAnyType::DEFAULT  => Format.new('%p').freeze,   # quoted string (Ruby inspect)
  }.freeze

  DEFAULT_ARRAY_FORMAT                          = Format.new('%a')
  DEFAULT_ARRAY_FORMAT.separator                = ','.freeze
  DEFAULT_ARRAY_FORMAT.separator2               = ','.freeze
  DEFAULT_ARRAY_FORMAT.container_string_formats = DEFAULT_CONTAINER_FORMATS
  DEFAULT_ARRAY_FORMAT.freeze

  DEFAULT_HASH_FORMAT                           = Format.new('%h')
  DEFAULT_HASH_FORMAT.separator                 = ','.freeze
  DEFAULT_HASH_FORMAT.separator2                = ' => '.freeze
  DEFAULT_HASH_FORMAT.container_string_formats  = DEFAULT_CONTAINER_FORMATS
  DEFAULT_HASH_FORMAT.freeze

  DEFAULT_HASH_DELIMITERS                       = ['{', '}'].freeze
  DEFAULT_ARRAY_DELIMITERS                      = ['[', ']'].freeze

  DEFAULT_STRING_FORMATS = {
    PFloatType::DEFAULT    => Format.new('%f').freeze,    # float
    PNumericType::DEFAULT  => Format.new('%d').freeze,    # decimal number
    PArrayType::DEFAULT    => DEFAULT_ARRAY_FORMAT.freeze,
    PHashType::DEFAULT     => DEFAULT_HASH_FORMAT.freeze,
    PAnyType::DEFAULT      => Format.new('%s').freeze,    # unquoted string
  }.freeze


  # Converts the given value to a String, under the direction of formatting rules per type.
  #
  # When converting to string it is possible to use a set of built in conversion rules.
  #
  # A format is specified on the form:
  # 
  # ´´´
  # %[Flags][Width][.Precision]Format
  # ´´´
  #
  # `Width` is the number of characters into which the value should be fitted. This allocated space is
  # padded if value is shorter. By default it is space padded, and the flag 0 will cause padding with 0
  # for numerical formats.
  #
  # `Precision` is the number of fractional digits to show for floating point, and the maximum characters
  # included in a string format.
  #
  # Note that all data type supports the formats `s` and `p` with the meaning "default to-string" and
  # "default-programmatic to-string".
  #
  # ### Integer
  #
  # | Format  | Integer Formats
  # | ------  | ---------------
  # | d       | Decimal, negative values produces leading '-'
  # | x X     | Hexadecimal in lower or upper case. Uses ..f/..F for negative values unless # is also used
  # | o       | Octal. Uses ..0 for negative values unless # is also used
  # | b B     | Binary with prefix 'b' or 'B'. Uses ..1/..1 for negative values unless # is also used
  # | c       | numeric value representing a Unicode value, result is a one unicode character string, quoted if alternative flag # is used
  # | s       | same as d, or d in quotes if alternative flag # is used
  # | p       | same as d
  # | eEfgGaA | converts integer to float and formats using the floating point rules
  #
  # Defaults to `d`
  #
  # ### Float
  #
  # | Format  | Float formats
  # | ------  | -------------
  # | f       | floating point in non exponential notation
  # | e E     | exponential notation with 'e' or 'E'
  # | g G     | conditional exponential with 'e' or 'E' if exponent < -4 or >= the precision
  # | a A     | hexadecimal exponential form, using 'x'/'X' as prefix and 'p'/'P' before exponent
  # | s       | converted to string using format p, then applying string formatting rule, alternate form # quotes result
  # | p       | f format with minimum significant number of fractional digits, prec has no effect
  # | dxXobBc | converts float to integer and formats using the integer rules
  #
  # Defaults to `p`
  #
  # ### String
  #
  # | Format | String
  # | ------ | ------
  # | s      | unquoted string, verbatim output of control chars
  # | p      | programmatic representation - strings are quoted, interior quotes and control chars are escaped
  # | C      | each :: name segment capitalized, quoted if alternative flag # is used
  # | c      | capitalized string, quoted if alternative flag # is used
  # | d      | downcased string, quoted if alternative flag # is used
  # | u      | upcased string, quoted if alternative flag # is used
  # | t      | trims leading and trailing whitespace from the string, quoted if alternative flag # is used
  #
  # Defaults to `s` at top level and `p` inside array or hash.
  #
  # ### Boolean
  # 
  # | Format    | Boolean Formats
  # | ----      | -------------------   
  # | t T       | 'true'/'false' or 'True'/'False' , first char if alternate form is used (i.e. 't'/'f' or 'T'/'F').
  # | y Y       | 'yes'/'no', 'Yes'/'No', 'y'/'n' or 'Y'/'N' if alternative flag # is used
  # | dxXobB    | numeric value 0/1 in accordance with the given format which must be valid integer format
  # | eEfgGaA   | numeric value 0.0/1.0 in accordance with the given float format and flags
  # | s         | 'true' / 'false'
  # | p         | 'true' / 'false'
  #
  # ### Regexp
  #
  # | Format    | Regexp Formats (%/)
  # | ----      | ------------------
  # | s         | / / delimiters, alternate flag replaces / delimiters with quotes
  # | p         | / / delimiters
  #
  # ### Undef
  #
  # | Format    | Undef formats
  # | ------    | -------------
  # | s         | empty string, or quoted empty string if alternative flag # is used
  # | p         | 'undef', or quoted '"undef"' if alternative flag # is used
  # | n         | 'nil', or 'null' if alternative flag # is used
  # | dxXobB    | 'NaN'
  # | eEfgGaA   | 'NaN'
  # | v         | 'n/a'
  # | V         | 'N/A'
  # | u         | 'undef', or 'undefined' if alternative # flag is used
  #
  # ### Default (value)
  # 
  # | Format    | Default formats
  # | ------    | ---------------
  # | d D       | 'default' or 'Default', alternative form # causes value to be quoted
  # | s         | same as d
  # | p         | same as d
  #
  # ### Array & Tuple
  #
  # | Format    | Array/Tuple Formats
  # | ------    | -------------
  # | a         | formats with `[ ]` delimiters and `,`, alternate form `#` indents nested arrays/hashes
  # | s         | same as a
  # | p         | same as a
  #
  # See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
  # more information about options.
  #
  # The alternate form flag `#` will cause indentation of nested array or hash containers. If width is also set
  # it is taken as the maximum allowed length of a sequence of elements (not including delimiters). If this max length
  # is exceeded, each element will be indented.
  #
  # ### Hash & Struct
  #
  # | Format    | Hash/Struct Formats
  # | ------    | -------------
  # | h         | formats with `{ }` delimiters, `,` element separator and ` => ` inner element separator unless overridden by flags 
  # | s         | same as h
  # | p         | same as h
  # | a         | converts the hash to an array of [k,v] tuples and formats it using array rule(s)
  # 
  # See "Flags" `<[({\|` for formatting of delimiters, and "Additional parameters for containers; Array and Hash" for
  # more information about options.
  #
  # The alternate form flag `#` will format each hash key/value entry indented on a separate line.
  #
  # ### Type
  # 
  # | Format    | Array/Tuple Formats
  # | ------    | -------------
  # | s        | The same as p, quoted if alternative flag # is used
  # | p        | Outputs the type in string form as specified by the Puppet Language
  #
  # ### Flags
  #
  # | Flag     | Effect 
  # | ------   | ------
  # | (space)  | space instead of + for numeric output (- is shown), for containers skips delimiters
  # | #        | alternate format; prefix 0x/0x, 0 (octal) and 0b/0B for binary, Floats force decimal '.'. For g/G keep trailing 0.
  # | +        | show sign +/- depending on value's sign, changes x,X, o,b, B format to not use 2's complement form
  # | -        | left justify the value in the given width
  # | 0        | pad with 0 instead of space for widths larger than value
  # | <[({\|   | defines an enclosing pair <> [] () {} or \| \| when used with a container type
  #
  # 
  # ### Additional parameters for containers; Array and Hash
  #
  # For containers (Array and Hash), the format is specified by a hash where the following keys can be set:
  # * `'format'` - the format specifier for the container itself
  # * `'separator'` - the separator string to use between elements, should not contain padding space at the end
  # * `'separator2'` - the separator string to use between association of hash entries key/value
  # * `'string_formats'´ - a map of type to format for elements contained in the container
  # 
  # Note that the top level format applies to Array and Hash objects contained/nested in an Array or a Hash.
  #
  # Given format mappings are merged with (default) formats and a format specified for a narrower type
  # wins over a broader.
  #
  # @param mode [String, Symbol] :strict or :extended (or :default which is the same as :strict)
  # @param string_formats [String, Hash] format tring, or a hash mapping type to a format string, and for Array and Hash types map to hash of details
  #
  def convert(value, string_formats = :default)
    options = DEFAULT_STRING_FORMATS

    value_type = TypeCalculator.infer_set(value)
    if string_formats.is_a?(String)
      # add the format given for the exact type
      string_formats = { value_type => string_formats }
    end

    case string_formats
    when :default
     # do nothing, use default formats

    when Hash
      # Convert and validate user input
      string_formats = validate_input(string_formats)
      # Merge user given with defaults such that user options wins, merge is deep and format specific
      options = Format.merge_string_formats(DEFAULT_STRING_FORMATS, string_formats)
    else
      raise ArgumentError, "string conversion expects a Default value or a Hash of type to format mappings, got a '#{string_formats.class}'"
    end

    _convert(value_type, value, options, DEFAULT_INDENTATION)
  end

#  # A method only used for manual debugging as the default output of the formatting rules is
#  # very hard to read otherwise.
#  #
#  # @api private
#  def dump_string_formats(f, indent = 1)
#     return f.to_s unless f.is_a?(Hash)
#     "{#{f.map {|k,v| "#{k.to_s} => #{dump_string_formats(v,indent+1)}"}.join(",\n#{'  '*indent}  ")}}"
#  end

  def _convert(val_type, value, format_map, indentation)
    @@string_visitor.visit_this_3(self, val_type, value, format_map, indentation)
  end
  private :_convert

  def validate_input(fmt)
    return nil if fmt.nil?
    unless fmt.is_a?(Hash)
      raise ArgumentError, "expected a hash with type to format mappings, got instance of '#{fmt.class}'"
    end
    fmt.reduce({}) do | result, entry|
      key, value = entry
      unless key.is_a?(Types::PAnyType)
        raise ArgumentError, "top level keys in the format hash must be data types, got instance of '#{key.class}'"
      end
      if value.is_a?(Hash)
        result[key] = validate_container_input(value)
      else
        result[key] = Format.new(value)
      end
      result
    end
  end
  private :validate_input

  FMT_KEYS = %w{separator separator2 format string_formats}.freeze

  def validate_container_input(fmt)
    if (fmt.keys - FMT_KEYS).size > 0
      raise ArgumentError, "only #{FMT_KEYS}.map {|k| "'#{k}'"}.join(', ')} are allowed in a container format, got #{fmt}"
    end
    result                          = Format.new(fmt['format'])
    result.separator                = fmt['separator']
    result.separator2               = fmt['separator2']
    result.container_string_formats = validate_input(fmt['string_formats'])
    result
  end
  private :validate_container_input

  def string_PRuntimeType(val_type, val, format_map)
    case (f = get_format(val_type, format_map))
    when :s
      val.to_s
    when :q
      val.to_s.inspect
    when :puppet
      puppet_safe(val.to_s)
    when :i, :d, :x, :o, :f, :puppet
      converted = convert(o, PNumericType) # rest is default
      "%#{f}" % converted
    else
      throw(:failed_conversion, [o, PStringType::DEFAULT, f])
    end
  end

  # Given an unsafe string make it safe for puppet
  def puppet_safe(str)
    str = str.inspect # all specials are now quoted
    # all $ variables must be quoted
    str.gsub!("\$", "\\\$")
    str
  end

  # Basically string_PAnyType converts the value to a String and then formats it according
  # to the resulting type
  #
  # @api private
  def string_PAnyType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    Kernel.format(f.orig_fmt, val)
  end

  def string_PDefaultType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    apply_string_flags(f, case f.format
    when :d, :s, :p
      f.alt? ? '"default"' : 'default'
    when :D
      f.alt? ? '"Default"' : 'Default'
    else
      raise FormatError.new('Default', f.format, 'dDsp')
    end)
  end

  # @api private
  def string_PUndefType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    apply_string_flags(f, case f.format
    when :n
      f.alt? ? 'null' : 'nil'
    when :u
      f.alt? ? 'undefined' : 'undef'
    when :d, :x, :X, :o, :b, :B, :e, :E, :f, :g, :G, :a, :A
      'NaN'
    when :v
      'n/a'
    when :V
      'N/A'
    when :s
      f.alt? ? '""' : ''
    when :p
      f.alt? ? '"undef"' : 'undef'
    else
      raise FormatError.new('Undef', f.format, 'nudxXobBeEfgGaAvVsp')
    end)
  end

  # @api private
  def string_PBooleanType(val_type, val, format_map, indentation)
    f = get_format(val_type, format_map)
    case f.format
    when :t
      # 'true'/'false' or 't'/'f' if in alt mode
      str_bool = val.to_s
      apply_string_flags(f, f.alt? ? str_bool[0] : str_bool)

    when :T
      # 'True'/'False' or 'T'/'F' if in alt mode
      str_bool = val.to_s.capitalize
      apply_string_flags(f, f.alt? ? str_bool[0] : str_bool)

    when :y
      # 'yes'/'no' or 'y'/'n' if in alt mode
      str_bool = val ? 'yes' : 'no'
      apply_string_flags(f, f.alt? ? str_bool[0] : str_bool)

    when :Y
      # 'Yes'/'No' or 'Y'/'N' if in alt mode
      str_bool = val ? 'Yes' : 'No'
      apply_string_flags(f, f.alt? ? str_bool[0] : str_bool)

    when :d, :x, :X, :o, :b, :B
      # Boolean in numeric form, formated by integer rule
      numeric_bool = val ? 1 : 0
      string_formats = { Puppet::Pops::Types::PIntegerType::DEFAULT => f}
      _convert(TypeCalculator.infer_set(numeric_bool), numeric_bool, string_formats, indentation)

    when :e, :E, :f, :g, :G, :a, :A
      # Boolean in numeric form, formated by float rule
      numeric_bool = val ? 1.0 : 0.0
      string_formats = { Puppet::Pops::Types::PFloatType::DEFAULT => f}
      _convert(TypeCalculator.infer_set(numeric_bool), numeric_bool, string_formats, indentation)

    when :s
      apply_string_flags(f, val.to_s)

    when :p
      apply_string_flags(f, val.inspect)

    else
      raise FormatError.new('Boolean', f.format, 'tTyYdxXobBeEfgGaAsp')
    end
  end

  # Performs post-processing of literals to apply width and precision flags
  def apply_string_flags(f, literal_str)
    if f.left || f.width || f.prec
      fmt = '%'
      fmt << '-' if f.left
      fmt << f.width.to_s if f.width
      fmt << '.' << f.prec.to_s if f.prec
      fmt << 's'
      Kernel.format(fmt, literal_str)
    else
      literal_str
    end
  end
  private :apply_string_flags

  # @api private
  def string_PIntegerType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    case f.format
    when :d, :x, :X, :o, :b, :B, :p
      Kernel.format(f.orig_fmt, val)

    when :e, :E, :f, :g, :G, :a, :A
      Kernel.format(f.orig_fmt, val.to_f)

    when :c
      char = [val].pack("U")
      char = f.alt? ? "\"#{char}\"" : char
      char = Kernel.format(f.orig_fmt.gsub('c','s'), char)

    when :s
      fmt = f.alt? ? 'p' : 's'
      int_str = Kernel.format('%d', val)
      Kernel.format(f.orig_fmt.gsub('s', fmt), int_str)

    else
      raise FormatError.new('Integer', f.format, 'dxXobBeEfgGaAspc')
    end
  end

  # @api private
  def string_PFloatType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    case f.format
    when :d, :x, :X, :o, :b, :B
      Kernel.format(f.orig_fmt, val.to_i)

    when :e, :E, :f, :g, :G, :a, :A, :p
      Kernel.format(f.orig_fmt, val)

    when :s
      float_str = f.alt? ? "\"#{Kernel.format('%p', val)}\"" : Kernel.format('%p', val)
      Kernel.format(f.orig_fmt, float_str)

    else
      raise FormatError.new('Float', f.format, 'dxXobBeEfgGaAsp')
    end
  end

  # @api private
  def string_PStringType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    case f.format
    when :s
      Kernel.format(f.orig_fmt, val)

    when :p
      apply_string_flags(f, puppet_quote(val))

    when :c
      c_val = val.capitalize
      f.alt? ? apply_string_flags(f, puppet_quote(c_val)) :  Kernel.format(f.orig_fmt.gsub('c', 's'), c_val)

    when :C
      c_val = val.split('::').map {|s| s.capitalize }.join('::')
      f.alt? ? apply_string_flags(f, puppet_quote(c_val)) :  Kernel.format(f.orig_fmt.gsub('C', 's'), c_val)

    when :u
      c_val = val.upcase
      f.alt? ? apply_string_flags(f, puppet_quote(c_val)) :  Kernel.format(f.orig_fmt.gsub('u', 's'), c_val)

    when :d
      c_val = val.downcase
      f.alt? ? apply_string_flags(f, puppet_quote(c_val)) :  Kernel.format(f.orig_fmt.gsub('d', 's'), c_val)

    when :t  # trim
      c_val = val.strip
      f.alt? ? apply_string_flags(f, puppet_quote(c_val)) :  Kernel.format(f.orig_fmt.gsub('t', 's'), c_val)

    else
      raise FormatError.new('String', f.format, 'cCudspt')
    end
  end

  # Performs a '%p' formatting of the given _str_ such that the output conforms to Puppet syntax. An ascii string
  # without control characters, dollar, single-qoute, or backslash, will be quoted using single quotes. All other
  # strings will be quoted using double quotes.
  #
  # @param [String] str the string that should be formatted
  # @return [String] the formatted string
  #
  # @api public
  def puppet_quote(str)
    if str.ascii_only? && (str =~ /(?:'|\$|\p{Cntrl}|\\)/).nil?
      "'#{str}'"
    else
      bld = '"'
      str.codepoints do |codepoint|
        case codepoint
        when 0x09
          bld << '\\t'
        when 0x0a
          bld << '\\n'
        when 0x0d
          bld << '\\r'
        when 0x22
          bld << '\\"'
        when 0x24
          bld << '\\$'
        when 0x5c
          bld << '\\\\'
        else
          if codepoint < 0x20 || codepoint > 0x7f
            bld << sprintf('\\u{%X}', codepoint)
          else
            bld.concat(codepoint)
          end
        end
      end
      bld << '"'
      bld
    end
  end

  # @api private
  def string_PRegexpType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    case f.format
    when :p
      Kernel.format(f.orig_fmt, val)
    when :s
      str_regexp = val.inspect
      str_regexp = f.alt? ? "\"#{str_regexp[1..-2]}\"" : str_regexp
      Kernel.format(f.orig_fmt, str_regexp)
    else
      raise FormatError.new('Regexp', f.format, 'rsp')
    end
  end

  def string_PArrayType(val_type, val, format_map, indentation)
    format         = get_format(val_type, format_map)
    sep            = format.separator || DEFAULT_ARRAY_FORMAT.separator
    string_formats = format.container_string_formats || DEFAULT_CONTAINER_FORMATS
    delims         = format.delimiter_pair(DEFAULT_ARRAY_DELIMITERS)

    # Make indentation active, if array is in alternative format, or if nested in indenting
    indentation = indentation.indenting(format.alt? || indentation.is_indenting?)

    case format.format
    when :a, :s, :p
      buf = ''
      if indentation.breaks?
        buf << "\n"
        buf << indentation.padding
      end
      buf << delims[0]

      # Make a first pass to format each element
      children_indentation = indentation.increase(format.alt?) # tell children they are expected to indent
      mapped = val.map do |v|
        if children_indentation.first?
          children_indentation = children_indentation.subsequent
        end
        val_t = TypeCalculator.infer_set(v)
        _convert(val_t, v, is_container?(val_t) ? format_map : string_formats, children_indentation)
      end

      # compute widest run in the array, skip nested arrays and hashes
      # then if size > width, set flag if a break on each element should be performed
      if format.alt? && format.width
        widest = val.each_with_index.reduce([0]) do | memo, v_i |
          # array or hash breaks
          if is_a_or_h?(v_i[0])
            memo << 0
          else
            memo[-1] += mapped[v_i[1]].length
          end
          memo
        end
        widest = widest.max
        sz_break = widest > (format.width || Float::INFINITY)
      else
        sz_break = false
      end

      # output each element with breaks and padding
      children_indentation = indentation.increase(format.alt?)
      val.each_with_index do |v, i|
        str_val = mapped[i]
        if children_indentation.first?
          children_indentation = children_indentation.subsequent
          # if breaking, indent first element by one
          if sz_break && !is_a_or_h?(v)
            buf << ' '
          end
        else
          buf << sep
          # if break on each (and breaking will not occur because next is an array or hash)
          # or, if indenting, and previous was an array or hash, then break and continue on next line
          # indented.
          if (sz_break && !is_a_or_h?(v)) || (format.alt? && i > 0 && is_a_or_h?(val[i-1]) && !is_a_or_h?(v))
            buf << "\n"
            buf << children_indentation.padding
          elsif !(format.alt? && is_a_or_h?(v))
            buf << ' '
          end
        end
        buf << str_val
      end
      buf << delims[1]
      buf
    else
      raise FormatError.new('Array', format.format, 'asp')
    end
  end

  def is_a_or_h?(x)
    x.is_a?(Array) || x.is_a?(Hash)
  end

  def is_container?(t)
    case t
    when PArrayType, PHashType, PStructType, PTupleType
      true
    else
      false
    end
  end

  # @api private
  def string_PTupleType(val_type, val, format_map, indentation)
    string_PArrayType(val_type, val, format_map, indentation)
  end

  # @api private
  def string_PIteratorType(val_type, val, format_map, indentation)
    v = val.to_a
    _convert(TypeCalculator.infer_set(v), v, format_map, indentation)
  end

  # @api private
  def string_PHashType(val_type, val, format_map, indentation)
    format         = get_format(val_type, format_map)
    sep            = format.separator  || DEFAULT_HASH_FORMAT.separator
    assoc          = format.separator2 || DEFAULT_HASH_FORMAT.separator2
    string_formats = format.container_string_formats || DEFAULT_CONTAINER_FORMATS
    delims         = format.delimiter_pair(DEFAULT_HASH_DELIMITERS)

    sep = format.alt? ? "#{sep}\n" : "#{sep} "

    cond_break     = ''
    padding        = ''

    case format.format
    when :a
      # Convert to array and use array rules
      array_hash = val.to_a
      _convert(TypeCalculator.infer_set(array_hash), array_hash, format_map, indentation)

    when :h, :s, :p
      indentation = indentation.indenting(format.alt? || indentation.is_indenting?)
      buf = ''
      if indentation.breaks?
        buf << "\n"
        buf << indentation.padding
      end

      children_indentation = indentation.increase
      if format.alt?
        cond_break = "\n"
        padding = children_indentation.padding
      end
      buf << delims[0]
      buf << cond_break  # break after opening delimiter if pretty printing
      buf << val.map do |k,v|
        key_type = TypeCalculator.infer_set(k)
        val_type = TypeCalculator.infer_set(v)
        key = _convert(key_type, k, is_container?(key_type) ? format_map : string_formats, children_indentation)
        val = _convert(val_type, v, is_container?(val_type) ? format_map : string_formats, children_indentation)
        "#{padding}#{key}#{assoc}#{val}"
      end.join(sep)
      if format.alt?
        buf << cond_break
        buf << indentation.padding
      end
      buf << delims[1]
      buf
    else
      raise FormatError.new('Hash', format.format, 'hasp')
    end
  end

  # @api private
  def string_PStructType(val_type, val, format_map, indentation)
    string_PHashType(val_type, val, format_map, indentation)
  end

  # @api private
  def string_PType(val_type, val, format_map, _)
    f = get_format(val_type, format_map)
    case f.format
    when :s
      str_val = f.alt? ? "\"#{val.to_s}\"" : val.to_s
      Kernel.format(f.orig_fmt, str_val)
    when :p
      Kernel.format(f.orig_fmt.gsub('p', 's'), val.to_s)
    else
      raise FormatError.new('Type', f.format, 'sp')
    end
  end

  # Maps the inferred type of o to a formatting rule
  def get_format(val_t, format_options)
    fmt = format_options.find {|k,_| k.assignable?(val_t) }
    return fmt[1] unless fmt.nil?
    return Format.new("%s")
  end
  private :get_format

end
end
end
