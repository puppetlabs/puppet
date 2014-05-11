# A setting that represents a span of time to live, and evaluates to Numeric
# seconds to live where 0 means shortest possible time to live, a positive numeric value means time
# to live in seconds, and the symbolic entry 'unlimited' is an infinite amount of time.
#
class Puppet::Settings::TTLSetting < Puppet::Settings::BaseSetting
  INFINITY = 1.0 / 0.0
  MANUAL = -INFINITY

  # How we convert from various units to seconds.
  UNITMAP = {
    # 365 days isn't technically a year, but is sufficient for most purposes
    "y" => 365 * 24 * 60 * 60,
    "d" => 24 * 60 * 60,
    "h" => 60 * 60,
    "m" => 60,
    "s" => 1
  }

  # A regex describing valid formats with groups for capturing the value and units
  FORMAT = /^(\d+)(y|d|h|m|s)?$/

  def type
    :ttl
  end

  # Convert the value to Numeric, parsing numeric string with units if necessary.
  def munge(value)
    self.class.munge(value, @name)
  end

  # Convert the value to Numeric, parsing numeric string with units if necessary.
  def self.munge(value, param_name)
    case
    when value == 'manual'
      MANUAL

    when value.is_a?(Numeric)
      if value < 0 && value != MANUAL
        raise Puppet::Settings::ValidationError, "Invalid negative 'time to live' #{value.inspect} - did you mean 'unlimited'?"
      end
      value

    when value == 'unlimited'
      INFINITY

    when (value.is_a?(String) and value =~ FORMAT)
      $1.to_i * UNITMAP[$2 || 's']
    else
      raise Puppet::Settings::ValidationError, "Invalid 'time to live' format '#{value.inspect}' for parameter: #{param_name}"
    end
  end

  def self.unmunge(ttl, param_name = 'unknown')
    case
    when ttl == MANUAL
      'manual'
    when ttl == INFINITY
      'unlimited'
    when ttl.is_a?(Numeric)
      multiples = [UNITMAP['y'], UNITMAP['d'], UNITMAP['h'], UNITMAP['m'], UNITMAP['s']]
      digits = []
      multiples.inject(ttl.to_f.round) do |total, multiple|
        # Divide into largest unit
        digits << total / multiple
        total % multiple # The remainder will be divided as the next largest
      end

      # format
      units = ['y','d','h','m','s']
      digits.zip(units).map { |v,u|
        if v > 0
          "#{v}#{u}"
        else
          nil
        end
      }.reject(&:nil?).join(" ")
    else
      raise Puppet::Settings::ValidationError, "Invalid 'time to live' format '#{ttl}' for parameter: #{param_name}"
    end
  end
end
