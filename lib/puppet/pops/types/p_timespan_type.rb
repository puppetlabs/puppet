module Puppet::Pops
module Types
  class PAbstractTimeDataType < PAbstractRangeType
    # @param from [AbstractTime] lower bound for this type. Nil or :default means unbounded
    # @param to [AbstractTime] upper bound for this type. Nil or :default means unbounded
    def initialize(from = nil, to = nil)
      super(convert_arg(from, true), convert_arg(to, false))
    end

    def convert_arg(arg, min)
      case arg
      when impl_class
        arg
      when Hash
        impl_class.from_hash(arg)
      when nil, :default
        nil
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

    def self.new_function(_, loader)
      @new_function ||= Puppet::Functions.create_loaded_function(:new_timespan, loader) do
        local_types do
          type 'Formats = Variant[String[2],Array[String[2]], 1]'
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
          Time::Timespan.from_fields(days, hours, minutes, seconds, milliseconds, microseconds, nanoseconds)
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

    DEFAULT = PTimespanType.new(nil, nil)
  end
end
end
