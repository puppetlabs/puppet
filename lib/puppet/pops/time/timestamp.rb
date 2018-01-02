module Puppet::Pops
module Time
class Timestamp < TimeData
  DEFAULT_FORMATS_WO_TZ = ['%FT%T.%N', '%FT%T', '%F %T.%N', '%F %T', '%F']
  DEFAULT_FORMATS = ['%FT%T.%N %Z', '%FT%T %Z', '%F %T.%N %Z', '%F %T %Z', '%F %Z'] + DEFAULT_FORMATS_WO_TZ

  CURRENT_TIMEZONE = 'current'.freeze
  KEY_TIMEZONE = 'timezone'.freeze

  # Converts a timezone that strptime can parse using '%z' into '-HH:MM' or '+HH:MM'
  # @param [String] tz the timezone to convert
  # @return [String] the converted timezone
  #
  # @api private
  def self.convert_timezone(tz)
    if tz =~ /\A[+-]\d\d:\d\d\z/
      tz
    else
      offset = utc_offset(tz) / 60
      if offset < 0
        offset = offset.abs
        sprintf('-%2.2d:%2.2d', offset / 60, offset % 60)
      else
        sprintf('+%2.2d:%2.2d', offset / 60, offset % 60)
      end
    end
  end

  # Returns the zone offset from utc for the given `timezone`
  # @param [String] timezone the timezone to get the offset for
  # @return [Integer] the timezone offset, in seconds
  #
  # @api private
  def self.utc_offset(timezone)
    if CURRENT_TIMEZONE.casecmp(timezone) == 0
      ::Time.now.utc_offset
    else
      hash = DateTime._strptime(timezone, '%z')
      offset = hash.nil? ? nil : hash[:offset]
      raise ArgumentError, _("Illegal timezone '%{timezone}'") % { timezone: timezone } if offset.nil?
      offset
    end
  end

  # Formats a ruby Time object using the given timezone
  def self.format_time(format, time, timezone)
    unless timezone.nil? || timezone.empty?
      time = time.localtime(convert_timezone(timezone))
    end
    time.strftime(format)
  end

  def self.now
    from_time(::Time.now)
  end

  def self.from_time(t)
    new(t.tv_sec * NSECS_PER_SEC + t.tv_nsec)
  end

  def self.from_hash(args_hash)
    parse(args_hash[KEY_STRING], args_hash[KEY_FORMAT], args_hash[KEY_TIMEZONE])
  end

  def self.parse(str, format = :default, timezone = nil)
    has_timezone = !(timezone.nil? || timezone.empty? || timezone == :default)
    if format.nil? || format == :default
      format = has_timezone ? DEFAULT_FORMATS_WO_TZ : DEFAULT_FORMATS
    end

    parsed = nil
    if format.is_a?(Array)
      format.each do |fmt|
        parsed = DateTime._strptime(str, fmt)
        next if parsed.nil?
        if parsed.include?(:leftover) || (has_timezone && parsed.include?(:zone))
          parsed = nil
          next
        end
        break
      end
      if parsed.nil?
        raise ArgumentError, _(
          "Unable to parse '%{str}' using any of the formats %{formats}") % { str: str, formats: format.join(', ') }
      end
    else
      parsed = DateTime._strptime(str, format)
      if parsed.nil? || parsed.include?(:leftover)
        raise ArgumentError, _("Unable to parse '%{str}' using format '%{format}'") % { str: str, format: format }
      end
      if has_timezone && parsed.include?(:zone)
        raise ArgumentError, _(
          'Using a Timezone designator in format specification is mutually exclusive to providing an explicit timezone argument')
      end
    end
    unless has_timezone
      timezone = parsed[:zone]
      has_timezone = !timezone.nil?
    end
    fraction = parsed[:sec_fraction]

    # Convert msec rational found in _strptime hash to usec
    fraction = fraction * 1000000 unless fraction.nil?

    # Create the Time instance and adjust for timezone
    parsed_time = ::Time.utc(parsed[:year], parsed[:mon], parsed[:mday], parsed[:hour], parsed[:min], parsed[:sec], fraction)
    parsed_time -= utc_offset(timezone) if has_timezone

    # Convert to Timestamp
    from_time(parsed_time)
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
      raise ArgumentError, _("%{klass} cannot be added to a Timestamp") % { klass: a_an_uc(o) }
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
      raise ArgumentError, _("%{klass} cannot be subtracted from a Timestamp") % { klass: a_an_uc(o) }
    end
  end

  def format(format, timezone = nil)
    self.class.format_time(format, to_time, timezone)
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
