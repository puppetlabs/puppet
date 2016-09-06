module Puppet::Pops
module Time
class Timestamp < TimeData
  DEFAULT_FORMATS = ['%FT%T.%L %Z', '%FT%T %Z', '%F %Z', '%FT%T.L', '%FT%T', '%F']

  def self.now
    from_time(::Time.now)
  end

  def self.from_time(t)
    new(t.tv_sec * NSECS_PER_SEC + t.tv_nsec)
  end

  def self.from_hash(args_hash)
    parse(args_hash[KEY_STRING], args_hash[KEY_FORMAT] || DEFAULT_FORMATS)
  end

  def self.parse(str, format = DEFAULT_FORMATS)
    if format.is_a?(Array)
      format.each do |fmt|
        begin
          return from_time(DateTime.strptime(str, fmt).to_time)
        rescue ArgumentError
        end
      end
      raise ArgumentError, "Unable to parse '#{str}' using any of the formats #{format.join(', ')}"
    end

    begin
      from_time(DateTime.strptime(str, format).to_time)
    rescue ArgumentError
      raise ArgumentError, "Unable to parse '#{str}' using format '#{format}'"
    end
  end

  undef_method :-@, :+@, :div, :fdiv, :abs, :abs2, :magnitude # does not make sense on a Timestamp
  if method_defined?(:negative?)
    undef_method :negative?, :positive?
  end
  if method_defined?(:%)
    undef_method :%, :modulo, :divmod
  end

  def +(o)
    case o
    when Timespan
      Timestamp.new(@nsecs + o.nsecs)
    when Integer, Float
      Timestamp.new(@nsecs + (o * NSECS_PER_SEC).to_i)
    else
      raise ArgumentError, "#{a_an_uc(o)} cannot be added to a Timestamp"
    end
  end

  def -(o)
    case o
    when Timestamp
      # Diff between two timestamps is a timespan
      Timespan.new(@nsecs - o.nsecs)
    when Timespan
      Timestamp.new(@nsecs - o.nsecs)
    when Integer, Float
      # Subtract seconds
      Timestamp.new(@nsecs - (o * NSECS_PER_SEC).to_i)
    else
      raise ArgumentError, "#{a_an_uc(o)} cannot be subtracted from a Timestamp"
    end
  end

  def format(format)
    to_time.strftime(format)
  end

  def to_s
    format(DEFAULT_FORMATS[0])
  end

  def to_time
    ::Time.at(to_r).utc
  end
end
end
end
