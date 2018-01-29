require 'strscan'

module PSON
  module Pure
    # This class implements the PSON parser that is used to parse a PSON string
    # into a Ruby data structure.
    class Parser < StringScanner
      STRING                = /" ((?:[^\x0-\x1f"\\] |
      #                              escaped special characters:
        \\["\\\/bfnrt] |
        \\u[0-9a-fA-F]{4} |
        #                          match all but escaped special characters:
          \\[\x20-\x21\x23-\x2e\x30-\x5b\x5d-\x61\x63-\x65\x67-\x6d\x6f-\x71\x73\x75-\xff])*)
            "/nx
      INTEGER               = /(-?0|-?[1-9]\d*)/
      FLOAT                 = /(-?
        (?:0|[1-9]\d*)
        (?:
          \.\d+(?i:e[+-]?\d+) |
          \.\d+ |
          (?i:e[+-]?\d+)
            )
            )/x
      NAN                   = /NaN/
      INFINITY              = /Infinity/
      MINUS_INFINITY        = /-Infinity/
      OBJECT_OPEN           = /\{/
      OBJECT_CLOSE          = /\}/
      ARRAY_OPEN            = /\[/
      ARRAY_CLOSE           = /\]/
      PAIR_DELIMITER        = /:/
      COLLECTION_DELIMITER  = /,/
      TRUE                  = /true/
      FALSE                 = /false/
      NULL                  = /null/
      IGNORE                = %r(
        (?:
        //[^\n\r]*[\n\r]| # line comments
        /\*               # c-style comments
        (?:
        [^*/]|        # normal chars
        /[^*]|        # slashes that do not start a nested comment
        \*[^/]|       # asterisks that do not end this comment
        /(?=\*/)      # single slash before this comment's end
        )*
        \*/               # the End of this comment
        |[ \t\r\n]+       # whitespaces: space, horizontal tab, lf, cr
      )+
      )mx

      UNPARSED = Object.new

      # Creates a new PSON::Pure::Parser instance for the string _source_.
      #
      # It will be configured by the _opts_ hash. _opts_ can have the following
      # keys:
      # * *max_nesting*: The maximum depth of nesting allowed in the parsed data
      #   structures. Disable depth checking with :max_nesting => false|nil|0,
      #   it defaults to 19.
      # * *allow_nan*: If set to true, allow NaN, Infinity and -Infinity in
      #   defiance of RFC 4627 to be parsed by the Parser. This option defaults
      #   to false.
      # * *object_class*: Defaults to Hash
      # * *array_class*: Defaults to Array
      def initialize(source, opts = {})
        source = convert_encoding source
        super source
        if !opts.key?(:max_nesting) # defaults to 19
          @max_nesting = 19
        elsif opts[:max_nesting]
          @max_nesting = opts[:max_nesting]
        else
          @max_nesting = 0
        end
        @allow_nan = !!opts[:allow_nan]
        @object_class = opts[:object_class] || Hash
        @array_class = opts[:array_class] || Array
      end

      alias source string

      # Parses the current PSON string _source_ and returns the complete data
      # structure as a result.
      def parse
        reset
        obj = nil
        until eos?
          case
          when scan(OBJECT_OPEN)
            obj and raise ParserError, "source '#{peek(20)}' not in PSON!"
            @current_nesting = 1
            obj = parse_object
          when scan(ARRAY_OPEN)
            obj and raise ParserError, "source '#{peek(20)}' not in PSON!"
            @current_nesting = 1
            obj = parse_array
          when skip(IGNORE)
            ;
          else
            raise ParserError, "source '#{peek(20)}' not in PSON!"
          end
        end
        obj or raise ParserError, "source did not contain any PSON!"
        obj
      end

      private

      def convert_encoding(source)
        if source.respond_to?(:to_str)
          source = source.to_str
        else
          raise TypeError, "#{source.inspect} is not like a string"
        end
        if supports_encodings?(source)
          if source.encoding == ::Encoding::ASCII_8BIT
            b = source[0, 4].bytes.to_a
            source =
              case
              when b.size >= 4 && b[0] == 0 && b[1] == 0 && b[2] == 0
                source.dup.force_encoding(::Encoding::UTF_32BE).encode!(::Encoding::UTF_8)
              when b.size >= 4 && b[0] == 0 && b[2] == 0
                source.dup.force_encoding(::Encoding::UTF_16BE).encode!(::Encoding::UTF_8)
              when b.size >= 4 && b[1] == 0 && b[2] == 0 && b[3] == 0
                source.dup.force_encoding(::Encoding::UTF_32LE).encode!(::Encoding::UTF_8)
              when b.size >= 4 && b[1] == 0 && b[3] == 0
                source.dup.force_encoding(::Encoding::UTF_16LE).encode!(::Encoding::UTF_8)
              else
                source.dup
              end
          else
            source = source.encode(::Encoding::UTF_8)
          end
          source.force_encoding(::Encoding::ASCII_8BIT)
        else
          b = source
          source =
            case
            when b.size >= 4 && b[0] == 0 && b[1] == 0 && b[2] == 0
              PSON.encode('utf-8', 'utf-32be', b)
            when b.size >= 4 && b[0] == 0 && b[2] == 0
              PSON.encode('utf-8', 'utf-16be', b)
            when b.size >= 4 && b[1] == 0 && b[2] == 0 && b[3] == 0
              PSON.encode('utf-8', 'utf-32le', b)
            when b.size >= 4 && b[1] == 0 && b[3] == 0
              PSON.encode('utf-8', 'utf-16le', b)
            else
              b
            end
        end
        source
      end

      def supports_encodings?(string)
        # Some modules, such as REXML on 1.8.7 (see #22804) can actually create
        # a top-level Encoding constant when they are misused. Therefore
        # checking for just that constant is not enough, so we'll be a bit more
        # robust about if we can actually support encoding transformations.
        string.respond_to?(:encoding) && defined?(::Encoding)
      end

      # Unescape characters in strings.
      UNESCAPE_MAP = Hash.new { |h, k| h[k] = k.chr }

        UNESCAPE_MAP.update(
          {
            ?"  => '"',
            ?\\ => '\\',
            ?/  => '/',
            ?b  => "\b",
            ?f  => "\f",
            ?n  => "\n",
            ?r  => "\r",
            ?t  => "\t",
            ?u  => nil,

      })

      def parse_string
        if scan(STRING)
          return '' if self[1].empty?
          string = self[1].gsub(%r{(?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff])}n) do |c|
            if u = UNESCAPE_MAP[$MATCH[1]]
              u
            else # \uXXXX
              bytes = ''
              i = 0
              while c[6 * i] == ?\\ && c[6 * i + 1] == ?u
                bytes << c[6 * i + 2, 2].to_i(16) << c[6 * i + 4, 2].to_i(16)
                i += 1
              end
              PSON.encode('utf-8', 'utf-16be', bytes)
            end
          end
          string.force_encoding(Encoding::UTF_8) if string.respond_to?(:force_encoding)
          string
        else
          UNPARSED
        end
      rescue => e
        raise GeneratorError, "Caught #{e.class}: #{e}", e.backtrace
      end

      def parse_value
        case
        when scan(FLOAT)
          Float(self[1])
        when scan(INTEGER)
          Integer(self[1])
        when scan(TRUE)
          true
        when scan(FALSE)
          false
        when scan(NULL)
          nil
        when (string = parse_string) != UNPARSED
          string
        when scan(ARRAY_OPEN)
          @current_nesting += 1
          ary = parse_array
          @current_nesting -= 1
          ary
        when scan(OBJECT_OPEN)
          @current_nesting += 1
          obj = parse_object
          @current_nesting -= 1
          obj
        when @allow_nan && scan(NAN)
          NaN
        when @allow_nan && scan(INFINITY)
          Infinity
        when @allow_nan && scan(MINUS_INFINITY)
          MinusInfinity
        else
          UNPARSED
        end
      end

      def parse_array
        raise NestingError, "nesting of #@current_nesting is too deep" if
          @max_nesting.nonzero? && @current_nesting > @max_nesting
        result = @array_class.new
        delim = false
        until eos?
          case
          when (value = parse_value) != UNPARSED
            delim = false
            result << value
            skip(IGNORE)
            if scan(COLLECTION_DELIMITER)
              delim = true
            elsif match?(ARRAY_CLOSE)
              ;
            else
              raise ParserError, "expected ',' or ']' in array at '#{peek(20)}'!"
            end
          when scan(ARRAY_CLOSE)
            raise ParserError, "expected next element in array at '#{peek(20)}'!" if delim
            break
          when skip(IGNORE)
            ;
          else
            raise ParserError, "unexpected token in array at '#{peek(20)}'!"
          end
        end
        result
      end

      def parse_object
        raise NestingError, "nesting of #@current_nesting is too deep" if
          @max_nesting.nonzero? && @current_nesting > @max_nesting
        result = @object_class.new
        delim = false
        until eos?
          case
          when (string = parse_string) != UNPARSED
            skip(IGNORE)
            raise ParserError, "expected ':' in object at '#{peek(20)}'!" unless scan(PAIR_DELIMITER)
            skip(IGNORE)
            unless (value = parse_value).equal? UNPARSED
              result[string] = value
              delim = false
              skip(IGNORE)
              if scan(COLLECTION_DELIMITER)
                delim = true
              elsif match?(OBJECT_CLOSE)
                ;
              else
                raise ParserError, "expected ',' or '}' in object at '#{peek(20)}'!"
              end
            else
              raise ParserError, "expected value in object at '#{peek(20)}'!"
            end
          when scan(OBJECT_CLOSE)
            raise ParserError, "expected next name, value pair in object at '#{peek(20)}'!" if delim
            break
          when skip(IGNORE)
            ;
          else
            raise ParserError, "unexpected token in object at '#{peek(20)}'!"
          end
        end
        result
      end
    end
  end
end
