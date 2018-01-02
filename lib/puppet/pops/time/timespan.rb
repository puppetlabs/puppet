module Puppet::Pops
module Time
  NSECS_PER_USEC = 1000
  NSECS_PER_MSEC = NSECS_PER_USEC * 1000
  NSECS_PER_SEC  = NSECS_PER_MSEC * 1000
  NSECS_PER_MIN  = NSECS_PER_SEC  * 60
  NSECS_PER_HOUR = NSECS_PER_MIN  * 60
  NSECS_PER_DAY  = NSECS_PER_HOUR * 24

  KEY_STRING = 'string'.freeze
  KEY_FORMAT = 'format'.freeze
  KEY_NEGATIVE = 'negative'.freeze
  KEY_DAYS = 'days'.freeze
  KEY_HOURS = 'hours'.freeze
  KEY_MINUTES = 'minutes'.freeze
  KEY_SECONDS = 'seconds'.freeze
  KEY_MILLISECONDS = 'milliseconds'.freeze
  KEY_MICROSECONDS = 'microseconds'.freeze
  KEY_NANOSECONDS = 'nanoseconds'.freeze

  # TimeData is a Numeric that stores its value internally as nano-seconds but will be considered to be seconds and fractions of
  # seconds when used in arithmetic or comparison with other Numeric types.
  #
  class TimeData < Numeric
    include LabelProvider

    attr_reader :nsecs

    def initialize(nanoseconds)
      @nsecs = nanoseconds
    end

    def <=>(o)
      case o
      when self.class
        @nsecs <=> o.nsecs
      when Integer
        to_int <=> o
      when Float
        to_f <=> o
      else
        nil
      end
    end

    def label(o)
      Utils.name_to_segments(o.class.name).last
    end

    # @return [Float] the number of seconds
    def to_f
      @nsecs.fdiv(NSECS_PER_SEC)
    end

    # @return [Integer] the number of seconds with fraction part truncated
    def to_int
      @nsecs / NSECS_PER_SEC
    end

    def to_i
      to_int
    end

    # @return [Complex] short for `#to_f.to_c`
    def to_c
      to_f.to_c
    end

    # @return [Rational] initial numerator is nano-seconds and denominator is nano-seconds per second
    def to_r
      Rational(@nsecs, NSECS_PER_SEC)
    end

    undef_method :phase, :polar, :rect, :rectangular
  end

  class Timespan < TimeData
    def self.from_fields(negative, days, hours, minutes, seconds, milliseconds = 0, microseconds = 0, nanoseconds = 0)
      ns = (((((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000 + milliseconds) * 1000 + microseconds) * 1000 + nanoseconds
      new(negative ? -ns : ns)
    end

    def self.from_hash(hash)
      hash.include?('string') ? from_string_hash(hash) : from_fields_hash(hash)
    end

    def self.from_string_hash(hash)
      parse(hash[KEY_STRING], hash[KEY_FORMAT] || Format::DEFAULTS)
    end

    def self.from_fields_hash(hash)
      from_fields(
        hash[KEY_NEGATIVE] || false,
        hash[KEY_DAYS] || 0,
        hash[KEY_HOURS] || 0,
        hash[KEY_MINUTES] || 0,
        hash[KEY_SECONDS] || 0,
        hash[KEY_MILLISECONDS] || 0,
        hash[KEY_MICROSECONDS] || 0,
        hash[KEY_NANOSECONDS] || 0)
    end

    def self.parse(str, format = Format::DEFAULTS)
      if format.is_a?(::Array)
        format.each do |fmt|
          fmt = FormatParser.singleton.parse_format(fmt) unless fmt.is_a?(Format)
          begin
            return fmt.parse(str)
          rescue ArgumentError
          end
        end
        raise ArgumentError, _("Unable to parse '%{str}' using any of the formats %{formats}") % { str: str, formats: format.join(', ') }
      end
      format = FormatParser.singleton.parse_format(format) unless format.is_a?(Format)
      format.parse(str)
    end

    # @return [true] if the stored value is negative
    def negative?
      @nsecs < 0
    end

    def +(o)
      case o
      when Timestamp
        Timestamp.new(@nsecs + o.nsecs)
      when Timespan
        Timespan.new(@nsecs + o.nsecs)
      when Integer, Float
        # Add seconds
        Timespan.new(@nsecs + (o * NSECS_PER_SEC).to_i)
      else
        raise ArgumentError, _("%{klass} cannot be added to a Timespan") % { klass: a_an_uc(o) } unless o.is_a?(Timespan)
      end
    end

    def -(o)
      case o
      when Timespan
        Timespan.new(@nsecs - o.nsecs)
      when Integer, Float
        # Subtract seconds
        Timespan.new(@nsecs - (o * NSECS_PER_SEC).to_i)
      else
        raise ArgumentError, _("%{klass} cannot be subtracted from a Timespan") % { klass: a_an_uc(o) }
      end
    end

    def -@
      Timespan.new(-@nsecs)
    end

    def *(o)
      case o
      when Integer, Float
        Timespan.new((@nsecs * o).to_i)
      else
        raise ArgumentError, _("A Timestamp cannot be multiplied by %{klass}") % { klass: a_an(o) }
      end
    end

    def divmod(o)
      case o
      when Integer
        to_i.divmod(o)
      when Float
        to_f.divmod(o)
      else
        raise ArgumentError, _("Can not do modulus on a Timespan using a %{klass}") % { klass: a_an(o) }
      end
    end

    def modulo(o)
      divmod(o)[1]
    end

    def %(o)
      modulo(o)
    end

    def div(o)
      case o
      when Timespan
        # Timespan/Timespan yields a Float
        @nsecs.fdiv(o.nsecs)
      when Integer, Float
        Timespan.new(@nsecs.div(o))
      else
        raise ArgumentError, _("A Timespan cannot be divided by %{klass}") % { klass: a_an(o) }
      end
    end

    def /(o)
      div(o)
    end

    # @return [Integer] a positive integer denoting the number of days
    def days
      total_days
    end

    # @return [Integer] a positive integer, 0 - 23 denoting hours of day
    def hours
      total_hours % 24
    end

    # @return [Integer] a positive integer, 0 - 59 denoting minutes of hour
    def minutes
      total_minutes % 60
    end

    # @return [Integer] a positive integer, 0 - 59 denoting seconds of minute
    def seconds
      total_seconds % 60
    end

    # @return [Integer] a positive integer, 0 - 999 denoting milliseconds of second
    def milliseconds
      total_milliseconds % 1000
    end

    # @return [Integer] a positive integer, 0 - 999.999.999 denoting nanoseconds of second
    def nanoseconds
      total_nanoseconds % NSECS_PER_SEC
    end

    # Formats this timestamp into a string according to the given `format`
    #
    # @param [String,Format] format The format to use when producing the string
    # @return [String] the string representing the formatted timestamp
    # @raise [ArgumentError] if the format is a string with illegal format characters
    # @api public
    def format(format)
      format = FormatParser.singleton.parse_format(format) unless format.is_a?(Format)
      format.format(self)
    end

    # Formats this timestamp into a string according to {Format::DEFAULTS[0]}
    #
    # @return [String] the string representing the formatted timestamp
    # @api public
    def to_s
      format(Format::DEFAULTS[0])
    end

    def to_hash(compact = false)
      result = {}
      n = nanoseconds
      if compact
        s = total_seconds
        result[KEY_SECONDS] = negative? ? -s : s
        result[KEY_NANOSECONDS] = negative? ? -n : n unless n == 0
      else
        add_unless_zero(result, KEY_DAYS, days)
        add_unless_zero(result, KEY_HOURS, hours)
        add_unless_zero(result, KEY_MINUTES, minutes)
        add_unless_zero(result, KEY_SECONDS, seconds)
        unless n == 0
          add_unless_zero(result, KEY_NANOSECONDS, n % 1000)
          n /= 1000
          add_unless_zero(result, KEY_MICROSECONDS, n % 1000)
          add_unless_zero(result, KEY_MILLISECONDS, n / 1000)
        end
        result[KEY_NEGATIVE] = true if negative?
      end
      result
    end

    def add_unless_zero(result, key, value)
      result[key] = value unless value == 0
    end
    private :add_unless_zero

    # @api private
    def total_days
      total_nanoseconds / NSECS_PER_DAY
    end

    # @api private
    def total_hours
      total_nanoseconds / NSECS_PER_HOUR
    end

    # @api private
    def total_minutes
      total_nanoseconds / NSECS_PER_MIN
    end

    # @api private
    def total_seconds
      total_nanoseconds / NSECS_PER_SEC
    end

    # @api private
    def total_milliseconds
      total_nanoseconds / NSECS_PER_MSEC
    end

    # @api private
    def total_microseconds
      total_nanoseconds / NSECS_PER_USEC
    end

    # @api private
    def total_nanoseconds
      @nsecs.abs
    end

    # Represents a compiled Timestamp format. The format is used both when parsing a timestamp
    # in string format and when producing a string from a timestamp instance.
    #
    class Format
      # A segment is either a string that will be represented literally in the formatted timestamp
      # or a value that corresponds to one of the possible format characters.
      class Segment
        def append_to(bld, ts)
          raise NotImplementedError, "'#{self.class.name}' should implement #append_to"
        end

        def append_regexp(bld, ts)
          raise NotImplementedError, "'#{self.class.name}' should implement #append_regexp"
        end

        def multiplier
          raise NotImplementedError, "'#{self.class.name}' should implement #multiplier"
        end
      end

      class LiteralSegment < Segment
        def append_regexp(bld)
          bld << "(#{Regexp.escape(@literal)})"
        end

        def initialize(literal)
          @literal = literal
        end

        def append_to(bld, ts)
          bld << @literal
        end

        def concat(codepoint)
          @literal.concat(codepoint)
        end

        def nanoseconds
          0
        end
      end

      class ValueSegment < Segment
        def initialize(padchar, width, default_width)
          @use_total = false
          @padchar = padchar
          @width = width
          @default_width = default_width
          @format = create_format
        end

        def create_format
          case @padchar
          when nil
            '%d'
          when ' '
            "%#{@width || @default_width}d"
          else
            "%#{@padchar}#{@width || @default_width}d"
          end
        end

        def append_regexp(bld)
          if @width.nil?
            case @padchar
            when nil
              bld << (use_total? ? '([0-9]+)' : "([0-9]{1,#{@default_width}})")
            when '0'
              bld << (use_total? ? '([0-9]+)' : "([0-9]{1,#{@default_width}})")
            else
              bld << (use_total? ? '\s*([0-9]+)' : "([0-9\\s]{1,#{@default_width}})")
            end
          else
            case @padchar
            when nil
              bld << "([0-9]{1,#{@width}})"
            when '0'
              bld << "([0-9]{#{@width}})"
            else
              bld << "([0-9\\s]{#{@width}})"
            end
          end
        end

        def nanoseconds(group)
          group.to_i * multiplier
        end

        def multiplier
          0
        end

        def set_use_total
          @use_total = true
        end

        def use_total?
          @use_total
        end

        def append_value(bld, n)
          bld << sprintf(@format, n)
        end
      end

      class DaySegment < ValueSegment
        def initialize(padchar, width)
          super(padchar, width, 1)
        end

        def multiplier
          NSECS_PER_DAY
        end

        def append_to(bld, ts)
          append_value(bld, ts.days)
        end
      end

      class HourSegment < ValueSegment
        def initialize(padchar, width)
          super(padchar, width, 2)
        end

        def multiplier
          NSECS_PER_HOUR
        end

        def append_to(bld, ts)
          append_value(bld, use_total? ? ts.total_hours : ts.hours)
        end
      end

      class MinuteSegment < ValueSegment
        def initialize(padchar, width)
          super(padchar, width, 2)
        end

        def multiplier
          NSECS_PER_MIN
        end

        def append_to(bld, ts)
          append_value(bld, use_total? ? ts.total_minutes : ts.minutes)
        end
      end

      class SecondSegment < ValueSegment
        def initialize(padchar, width)
          super(padchar, width, 2)
        end

        def multiplier
          NSECS_PER_SEC
        end

        def append_to(bld, ts)
          append_value(bld, use_total? ? ts.total_seconds : ts.seconds)
        end
      end

      # Class that assumes that leading zeroes are significant and that trailing zeroes are not and left justifies when formatting.
      # Applicable after a decimal point, and hence to the %L and %N formats.
      class FragmentSegment < ValueSegment
        def nanoseconds(group)
          # Using %L or %N to parse a string only makes sense when they are considered to be fractions. Using them
          # as a total quantity would introduce ambiguities.
          raise ArgumentError, _('Format specifiers %L and %N denotes fractions and must be used together with a specifier of higher magnitude') if use_total?
          n = group.to_i
          p = 9 - group.length
          p <= 0 ? n : n * 10 ** p
        end

        def create_format
          if @padchar.nil?
            '%d'
          else
            "%-#{@width || @default_width}d"
          end
        end

        def append_value(bld, n)
          # Strip trailing zeroes when default format is used
          n = n.to_s.sub(/\A([0-9]+?)0*\z/, '\1').to_i unless use_total? || @padchar == '0'
          super(bld, n)
        end
      end

      class MilliSecondSegment < FragmentSegment
        def initialize(padchar, width)
          super(padchar, width, 3)
        end

        def multiplier
          NSECS_PER_MSEC
        end

        def append_to(bld, ts)
          append_value(bld, use_total? ? ts.total_milliseconds : ts.milliseconds)
        end
      end

      class NanoSecondSegment < FragmentSegment
        def initialize(padchar, width)
          super(padchar, width, 9)
        end

        def multiplier
          width = @width || @default_width
          if width < 9
            10 ** (9 - width)
          else
            1
          end
        end

        def append_to(bld, ts)
          ns = ts.total_nanoseconds
          width = @width || @default_width
          if width < 9
            # Truncate digits to the right, i.e. let %6N reflect microseconds
            ns /= 10 ** (9 - width)
            ns %= 10 ** width unless use_total?
          else
            ns %= NSECS_PER_SEC unless use_total?
          end
          append_value(bld, ns)
        end
      end

      def initialize(format, segments)
        @format = format.freeze
        @segments = segments.freeze
      end

      def format(timespan)
        bld = timespan.negative? ? '-' : ''
        @segments.each { |segment| segment.append_to(bld, timespan) }
        bld
      end

      def parse(timespan)
        md = regexp.match(timespan)
        raise ArgumentError, _("Unable to parse '%{timespan}' using format '%{format}'") % { timespan: timespan, format: @format } if md.nil?
        nanoseconds = 0
        md.captures.each_with_index do |group, index|
          segment = @segments[index]
          next if segment.is_a?(LiteralSegment)
          group.lstrip!
          raise ArgumentError, _("Unable to parse '%{timespan}' using format '%{format}'") % { timespan: timespan, format: @format } unless group =~ /\A[0-9]+\z/
          nanoseconds += segment.nanoseconds(group)
        end
        Timespan.new(timespan.start_with?('-') ? -nanoseconds : nanoseconds)
      end

      def to_s
        @format
      end

      private

      def regexp
        @regexp ||= build_regexp
      end

      def build_regexp
        bld = '\A-?'
        @segments.each { |segment| segment.append_regexp(bld) }
        bld << '\z'
        Regexp.new(bld)
      end
    end

    # Parses a string into a Timestamp::Format instance
    class FormatParser
      def self.singleton
        @singleton
      end

      def initialize
        @formats = Hash.new { |hash, str| hash[str] = internal_parse(str) }
      end

      def parse_format(format)
        @formats[format]
      end

      private

      NSEC_MAX = 0
      MSEC_MAX = 1
      SEC_MAX = 2
      MIN_MAX = 3
      HOUR_MAX = 4
      DAY_MAX = 5

      SEGMENT_CLASS_BY_ORDINAL = [
        Format::NanoSecondSegment, Format::MilliSecondSegment, Format::SecondSegment, Format::MinuteSegment, Format::HourSegment, Format::DaySegment
      ]

      def bad_format_specifier(format, start, position)
        _("Bad format specifier '%{expression}' in '%{format}', at position %{position}") % { expression: format[start,position-start], format: format, position: position }
      end

      def append_literal(bld, codepoint)
        if bld.empty? || !bld.last.is_a?(Format::LiteralSegment)
          bld << Format::LiteralSegment.new(''.concat(codepoint))
        else
          bld.last.concat(codepoint)
        end
      end

      # States used by the #internal_parser function
      STATE_LITERAL = 0 # expects literal or '%'
      STATE_PAD  = 1 # expects pad, width, or format character
      STATE_WIDTH = 2 # expects width, or format character

      def internal_parse(str)
        bld = []
        raise ArgumentError, _('Format must be a String') unless str.is_a?(String)
        highest = -1
        state = STATE_LITERAL
        padchar = '0'
        width = nil
        position = -1
        fstart = 0

        str.codepoints do |codepoint|
          position += 1
          if state == STATE_LITERAL
            if codepoint == 0x25 # '%'
              state = STATE_PAD
              fstart = position
              padchar = '0'
              width = nil
            else
              append_literal(bld, codepoint)
            end
            next
          end

          case codepoint
          when 0x25 # '%'
            append_literal(bld, codepoint)
            state = STATE_LITERAL
          when 0x2D # '-'
            raise ArgumentError, bad_format_specifier(str, fstart, position) unless state == STATE_PAD
            padchar = nil
            state = STATE_WIDTH
          when 0x5F # '_'
            raise ArgumentError, bad_format_specifier(str, fstart, position) unless state == STATE_PAD
            padchar = ' '
            state = STATE_WIDTH
          when 0x44 # 'D'
            highest = DAY_MAX
            bld << Format::DaySegment.new(padchar, width)
            state = STATE_LITERAL
          when 0x48 # 'H'
            highest = HOUR_MAX unless highest > HOUR_MAX
            bld << Format::HourSegment.new(padchar, width)
            state = STATE_LITERAL
          when 0x4D # 'M'
            highest = MIN_MAX unless highest > MIN_MAX
            bld << Format::MinuteSegment.new(padchar, width)
            state = STATE_LITERAL
          when 0x53 # 'S'
            highest = SEC_MAX unless highest > SEC_MAX
            bld << Format::SecondSegment.new(padchar, width)
            state = STATE_LITERAL
          when 0x4C # 'L'
            highest = MSEC_MAX unless highest > MSEC_MAX
            bld << Format::MilliSecondSegment.new(padchar, width)
            state = STATE_LITERAL
          when 0x4E # 'N'
            highest = NSEC_MAX unless highest > NSEC_MAX
            bld << Format::NanoSecondSegment.new(padchar, width)
            state = STATE_LITERAL
          else # only digits allowed at this point
            raise ArgumentError, bad_format_specifier(str, fstart, position) unless codepoint >= 0x30 && codepoint <= 0x39
            if state == STATE_PAD && codepoint == 0x30
              padchar = '0'
            else
              n = codepoint - 0x30
              if width.nil?
                width = n
              else
                width = width * 10 + n
              end
            end
            state = STATE_WIDTH
          end
        end

        raise ArgumentError, bad_format_specifier(str, fstart, position)  unless state == STATE_LITERAL
        unless highest == -1
          hc = SEGMENT_CLASS_BY_ORDINAL[highest]
          bld.find { |s| s.instance_of?(hc) }.set_use_total
        end
        Format.new(str, bld)
      end

      @singleton = FormatParser.new
    end

    class Format
      DEFAULTS = ['%D-%H:%M:%S.%-N', '%H:%M:%S.%-N', '%M:%S.%-N', '%S.%-N', '%D-%H:%M:%S', '%H:%M:%S', '%D-%H:%M', '%S'].map { |str| FormatParser.singleton.parse_format(str) }
    end
  end
end
end
