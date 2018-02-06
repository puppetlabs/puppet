# A setting that represents a span of time to live, and evaluates to Numeric
# seconds to live where 0 means shortest possible time to live, a positive numeric value means time
# to live in seconds, and the symbolic entry 'unlimited' is an infinite amount of time.
#
class Puppet::Settings::TTLSetting < Puppet::Settings::BaseSetting
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

  def print(value)
    val = munge(value)
    val == Float::INFINITY ? 'unlimited' : val
  end

  # Convert the value to Numeric, parsing numeric string with units if necessary.
  def self.munge(value, param_name)
    case
    when value.is_a?(Numeric)
      if value < 0
        raise Puppet::Settings::ValidationError, _("Invalid negative 'time to live' %{value} - did you mean 'unlimited'?") % { value: value.inspect }
      end
      value

    when value == 'unlimited'
      Float::INFINITY

    when (value.is_a?(String) and value =~ FORMAT)
      $1.to_i * UNITMAP[$2 || 's']
    else
      raise Puppet::Settings::ValidationError, _("Invalid 'time to live' format '%{value}' for parameter: %{param_name}") % { value: value.inspect, param_name: param_name }
    end
  end
end
