module Puppet::Pops
module Types
  class PAbstractTimeDataType < PScalarType
    # @param from [AbstractTime] lower bound for this type. Nil or :default means unbounded
    # @param to [AbstractTime] upper bound for this type. Nil or :default means unbounded
    def initialize(from, to = nil)
      @from = convert_arg(from, true)
      @to = convert_arg(to, false)
      raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{@from}, #{@to}" unless @from <= @to
    end

    # Checks if this numeric range intersects with another
    #
    # @param o [PNumericType] the range to compare with
    # @return [Boolean] `true` if this range intersects with the other range
    # @api public
    def intersect?(o)
      self.class == o.class && !(@to < o.numeric_from || o.numeric_to < @from)
    end

    # Returns the lower bound of the numeric range or `nil` if no lower bound is set.
    # @return [Float,Integer]
    def from
      @from == -Float::INFINITY ? nil : @from
    end

    # Returns the upper bound of the numeric range or `nil` if no upper bound is set.
    # @return [Float,Integer]
    def to
      @to == Float::INFINITY ? nil : @to
    end

    # Same as #from but will return `-Float::Infinity` instead of `nil` if no lower bound is set.
    # @return [Float,Integer]
    def numeric_from
      @from
    end

    # Same as #to but will return `Float::Infinity` instead of `nil` if no lower bound is set.
    # @return [Float,Integer]
    def numeric_to
      @to
    end

    def hash
      @from.hash ^ @to.hash
    end

    def eql?(o)
      self.class == o.class && @from == o.numeric_from && @to == o.numeric_to
    end

    def unbounded?
      @from == -Float::INFINITY && @to == Float::INFINITY
    end

    def convert_arg(arg, min)
      case arg
      when impl_class
        arg
      when Hash
        impl_class.from_hash(arg)
      when nil, :default
        min ? -Float::INFINITY : Float::INFINITY
      when String
        impl_class.parse(arg)
      when Integer
        arg == impl_class.new(arg * Time::NSECS_PER_SEC)
      when Float
        arg == (min ? -Float::INFINITY : Float::INFINITY) ? arg : impl_class.new(arg * Time::NSECS_PER_SEC)
      else
        raise ArgumentError, "Unable to create a #{impl_class.name} from a #{arg.class.name}" unless arg.nil? || arg == :default
        nil
      end
    end

    # Concatenates this range with another range provided that the ranges intersect or
    # are adjacent. When that's not the case, this method will return `nil`
    #
    # @param o [PAbstractTimeDataType] the range to concatenate with this range
    # @return [PAbstractTimeDataType,nil] the concatenated range or `nil` when the ranges were apart
    # @api public
    def merge(o)
      if intersect?(o) || adjacent?(o)
        new_min = numeric_from <= o.numeric_from ? numeric_from : o.numeric_from
        new_max = numeric_to >= o.numeric_to ? numeric_to : o.numeric_to
        self.class.new(new_min, new_max)
      else
        nil
      end
    end

    def _assignable?(o, guard)
      self.class == o.class && numeric_from <= o.numeric_from && numeric_to >= o.numeric_to
    end
  end

  class PTimespanType < PAbstractTimeDataType
    def self.register_ptype(loader, ir)
      create_ptype(loader, ir, 'ScalarType',
        'from' => { KEY_TYPE => POptionalType.new(PTimespanType::DEFAULT), KEY_VALUE => nil },
        'to' => { KEY_TYPE => POptionalType.new(PTimespanType::DEFAULT), KEY_VALUE => nil }
      )
    end

    def self.new_function(type)
      @new_function ||= Puppet::Functions.create_loaded_function(:new_timespan, type.loader) do
        local_types do
          type 'Formats = Variant[String[2],Array[String[2], 1]]'
        end

        dispatch :from_seconds do
          param           'Variant[Integer,Float]', :seconds
        end

        dispatch :from_string do
          param           'String[1]', :string
          optional_param  'Formats', :format
        end

        dispatch :from_fields do
          param          'Integer', :days
          param          'Integer', :hours
          param          'Integer', :minutes
          param          'Integer', :seconds
          optional_param 'Integer', :milliseconds
          optional_param 'Integer', :microseconds
          optional_param 'Integer', :nanoseconds
        end

        dispatch :from_string_hash do
          param <<-TYPE, :hash_arg
            Struct[{
              string => String[1],
              Optional[format] => Formats
            }]
          TYPE
        end

        dispatch :from_fields_hash do
          param <<-TYPE, :hash_arg
            Struct[{
              Optional[negative] => Boolean,
              Optional[days] => Integer,
              Optional[hours] => Integer,
              Optional[minutes] => Integer,
              Optional[seconds] => Integer,
              Optional[milliseconds] => Integer,
              Optional[microseconds] => Integer,
              Optional[nanoseconds] => Integer
            }]
          TYPE
        end

        def from_seconds(seconds)
          Time::Timespan.new((seconds * Time::NSECS_PER_SEC).to_i)
        end

        def from_string(string, format = Time::Timespan::Format::DEFAULTS)
          Time::Timespan.parse(string, format)
        end

        def from_fields(days, hours, minutes, seconds, milliseconds = 0, microseconds = 0, nanoseconds = 0)
          Time::Timespan.from_fields(false, days, hours, minutes, seconds, milliseconds, microseconds, nanoseconds)
        end

        def from_string_hash(args_hash)
          Time::Timespan.from_string_hash(args_hash)
        end

        def from_fields_hash(args_hash)
          Time::Timespan.from_fields_hash(args_hash)
        end
      end
    end

    def generalize
      DEFAULT
    end

    def impl_class
      Time::Timespan
    end

    def instance?(o, guard = nil)
      o.is_a?(Time::Timespan) && o >= @from && o <= @to
    end

    DEFAULT = PTimespanType.new(nil, nil)
  end
end
end
