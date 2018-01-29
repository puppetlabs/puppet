module PSON
  MAP = {
    "\x0" => '\u0000',
    "\x1" => '\u0001',
    "\x2" => '\u0002',
    "\x3" => '\u0003',
    "\x4" => '\u0004',
    "\x5" => '\u0005',
    "\x6" => '\u0006',
    "\x7" => '\u0007',
    "\b"  =>  '\b',
    "\t"  =>  '\t',
    "\n"  =>  '\n',
    "\xb" => '\u000b',
    "\f"  =>  '\f',
    "\r"  =>  '\r',
    "\xe" => '\u000e',
    "\xf" => '\u000f',
    "\x10" => '\u0010',
    "\x11" => '\u0011',
    "\x12" => '\u0012',
    "\x13" => '\u0013',
    "\x14" => '\u0014',
    "\x15" => '\u0015',
    "\x16" => '\u0016',
    "\x17" => '\u0017',
    "\x18" => '\u0018',
    "\x19" => '\u0019',
    "\x1a" => '\u001a',
    "\x1b" => '\u001b',
    "\x1c" => '\u001c',
    "\x1d" => '\u001d',
    "\x1e" => '\u001e',
    "\x1f" => '\u001f',
    '"'   =>  '\"',
    '\\'  =>  '\\\\',
  } # :nodoc:

  # Convert a UTF8 encoded Ruby string _string_ to a PSON string, encoded with
  # UTF16 big endian characters as \u????, and return it.
  if String.method_defined?(:force_encoding)
    def utf8_to_pson(string) # :nodoc:
      string = string.dup
      string << '' # XXX workaround: avoid buffer sharing
      string.force_encoding(Encoding::ASCII_8BIT)
      string.gsub!(/["\\\x0-\x1f]/) { MAP[$MATCH] }
      string
    rescue => e
      raise GeneratorError, "Caught #{e.class}: #{e}", e.backtrace
    end
  else
    def utf8_to_pson(string) # :nodoc:
      string.gsub(/["\\\x0-\x1f]/n) { MAP[$MATCH] }
    end
  end
  module_function :utf8_to_pson

  module Pure
    module Generator
      # This class is used to create State instances, that are use to hold data
      # while generating a PSON text from a Ruby data structure.
      class State
        # Creates a State object from _opts_, which ought to be Hash to create
        # a new State instance configured by _opts_, something else to create
        # an unconfigured instance. If _opts_ is a State object, it is just
        # returned.
        def self.from_state(opts)
          case opts
          when self
            opts
          when Hash
            new(opts)
          else
            new
          end
        end

        # Instantiates a new State object, configured by _opts_.
        #
        # _opts_ can have the following keys:
        #
        # * *indent*: a string used to indent levels (default: ''),
        # * *space*: a string that is put after, a : or , delimiter (default: ''),
        # * *space_before*: a string that is put before a : pair delimiter (default: ''),
        # * *object_nl*: a string that is put at the end of a PSON object (default: ''),
        # * *array_nl*: a string that is put at the end of a PSON array (default: ''),
        # * *check_circular*: true if checking for circular data structures
        #   should be done (the default), false otherwise.
        # * *check_circular*: true if checking for circular data structures
        #   should be done, false (the default) otherwise.
        # * *allow_nan*: true if NaN, Infinity, and -Infinity should be
        #   generated, otherwise an exception is thrown, if these values are
        #   encountered. This options defaults to false.
        def initialize(opts = {})
          @seen = {}
          @indent         = ''
          @space          = ''
          @space_before   = ''
          @object_nl      = ''
          @array_nl       = ''
          @check_circular = true
          @allow_nan      = false
          configure opts
        end

        # This string is used to indent levels in the PSON text.
        attr_accessor :indent

        # This string is used to insert a space between the tokens in a PSON
        # string.
        attr_accessor :space

        # This string is used to insert a space before the ':' in PSON objects.
        attr_accessor :space_before

        # This string is put at the end of a line that holds a PSON object (or
        # Hash).
        attr_accessor :object_nl

        # This string is put at the end of a line that holds a PSON array.
        attr_accessor :array_nl

        # This integer returns the maximum level of data structure nesting in
        # the generated PSON, max_nesting = 0 if no maximum is checked.
        attr_accessor :max_nesting

        def check_max_nesting(depth) # :nodoc:
          return if @max_nesting.zero?
          current_nesting = depth + 1
          current_nesting > @max_nesting and
            raise NestingError, "nesting of #{current_nesting} is too deep"
        end

        # Returns true, if circular data structures should be checked,
        # otherwise returns false.
        def check_circular?
          @check_circular
        end

        # Returns true if NaN, Infinity, and -Infinity should be considered as
        # valid PSON and output.
        def allow_nan?
          @allow_nan
        end

        # Returns _true_, if _object_ was already seen during this generating
        # run.
        def seen?(object)
          @seen.key?(object.__id__)
        end

        # Remember _object_, to find out if it was already encountered (if a
        # cyclic data structure is if a cyclic data structure is rendered).
        def remember(object)
          @seen[object.__id__] = true
        end

        # Forget _object_ for this generating run.
        def forget(object)
          @seen.delete object.__id__
        end

        # Configure this State instance with the Hash _opts_, and return
        # itself.
        def configure(opts)
          @indent         = opts[:indent] if opts.key?(:indent)
          @space          = opts[:space] if opts.key?(:space)
          @space_before   = opts[:space_before] if opts.key?(:space_before)
          @object_nl      = opts[:object_nl] if opts.key?(:object_nl)
          @array_nl       = opts[:array_nl] if opts.key?(:array_nl)
          @check_circular = !!opts[:check_circular] if opts.key?(:check_circular)
          @allow_nan      = !!opts[:allow_nan] if opts.key?(:allow_nan)
          if !opts.key?(:max_nesting) # defaults to 19
            @max_nesting = 19
          elsif opts[:max_nesting]
            @max_nesting = opts[:max_nesting]
          else
            @max_nesting = 0
          end
          self
        end

        # Returns the configuration instance variables as a hash, that can be
        # passed to the configure method.
        def to_h
          result = {}
          for iv in %w{indent space space_before object_nl array_nl check_circular allow_nan max_nesting}
            result[iv.intern] = instance_variable_get("@#{iv}")
          end
          result
        end
      end

      module GeneratorMethods
        module Object
          # Converts this object to a string (calling #to_s), converts
          # it to a PSON string, and returns the result. This is a fallback, if no
          # special method #to_pson was defined for some object.
          def to_pson(*) to_s.to_pson end
        end

        module Hash
          # Returns a PSON string containing a PSON object, that is unparsed from
          # this Hash instance.
          # _state_ is a PSON::State object, that can also be used to configure the
          # produced PSON string output further.
          # _depth_ is used to find out nesting depth, to indent accordingly.
          def to_pson(state = nil, depth = 0, *)
            if state
              state = PSON.state.from_state(state)
              state.check_max_nesting(depth)
              pson_check_circular(state) { pson_transform(state, depth) }
            else
              pson_transform(state, depth)
            end
          end

          private

          def pson_check_circular(state)
            if state and state.check_circular?
              state.seen?(self) and raise PSON::CircularDatastructure,
                "circular data structures not supported!"
              state.remember self
            end
            yield
          ensure
            state and state.forget self
          end

          def pson_shift(state, depth)
            state and not state.object_nl.empty? or return ''
            state.indent * depth
          end

          def pson_transform(state, depth)
            delim = ','
            if state
              delim << state.object_nl
              result = '{'
              result << state.object_nl
              result << map { |key,value|
                s = pson_shift(state, depth + 1)
                s << key.to_s.to_pson(state, depth + 1)
                s << state.space_before
                s << ':'
                s << state.space
                s << value.to_pson(state, depth + 1)
              }.join(delim)
              result << state.object_nl
              result << pson_shift(state, depth)
              result << '}'
            else
              result = '{'
              result << map { |key,value|
                key.to_s.to_pson << ':' << value.to_pson
              }.join(delim)
              result << '}'
            end
            result
          end
        end

        module Array
          # Returns a PSON string containing a PSON array, that is unparsed from
          # this Array instance.
          # _state_ is a PSON::State object, that can also be used to configure the
          # produced PSON string output further.
          # _depth_ is used to find out nesting depth, to indent accordingly.
          def to_pson(state = nil, depth = 0, *)
            if state
              state = PSON.state.from_state(state)
              state.check_max_nesting(depth)
              pson_check_circular(state) { pson_transform(state, depth) }
            else
              pson_transform(state, depth)
            end
          end

          private

          def pson_check_circular(state)
            if state and state.check_circular?
              state.seen?(self) and raise PSON::CircularDatastructure,
                "circular data structures not supported!"
              state.remember self
            end
            yield
          ensure
            state and state.forget self
          end

          def pson_shift(state, depth)
            state and not state.array_nl.empty? or return ''
            state.indent * depth
          end

          def pson_transform(state, depth)
            delim = ','
            if state
              delim << state.array_nl
              result = '['
              result << state.array_nl
              result << map { |value|
                pson_shift(state, depth + 1) << value.to_pson(state, depth + 1)
              }.join(delim)
              result << state.array_nl
              result << pson_shift(state, depth)
              result << ']'
            else
              '[' << map { |value| value.to_pson }.join(delim) << ']'
            end
          end
        end

        module Integer
          # Returns a PSON string representation for this Integer number.
          def to_pson(*) to_s end
        end

        module Float
          # Returns a PSON string representation for this Float number.
          def to_pson(state = nil, *)
            if infinite? || nan?
              if !state || state.allow_nan?
                to_s
              else
                raise GeneratorError, "#{self} not allowed in PSON"
              end
            else
              to_s
            end
          end
        end

        module String
          # This string should be encoded with UTF-8 A call to this method
          # returns a PSON string encoded with UTF16 big endian characters as
          # \u????.
          def to_pson(*)
            '"' << PSON.utf8_to_pson(self) << '"'
          end

          # Module that holds the extending methods if, the String module is
          # included.
          module Extend
            # Raw Strings are PSON Objects (the raw bytes are stored in an array for the
            # key "raw"). The Ruby String can be created by this module method.
            def pson_create(o)
              o['raw'].pack('C*')
            end
          end

          # Extends _modul_ with the String::Extend module.
          def self.included(modul)
            modul.extend Extend
          end

          # This method creates a raw object hash, that can be nested into
          # other data structures and will be unparsed as a raw string. This
          # method should be used, if you want to convert raw strings to PSON
          # instead of UTF-8 strings, e.g. binary data.
          def to_pson_raw_object
            # create_id will be ignored during deserialization
            {
              PSON.create_id  => self.class.name,
              'raw'           => self.unpack('C*'),
            }
          end

          # This method creates a PSON text from the result of
          # a call to to_pson_raw_object of this String.
          def to_pson_raw(*args)
            to_pson_raw_object.to_pson(*args)
          end
        end

        module TrueClass
          # Returns a PSON string for true: 'true'.
          def to_pson(*) 'true' end
        end

        module FalseClass
          # Returns a PSON string for false: 'false'.
          def to_pson(*) 'false' end
        end

        module NilClass
          # Returns a PSON string for nil: 'null'.
          def to_pson(*) 'null' end
        end
      end
    end
  end
end
