# A setting that represents a span of time, and evaluates to an integer
# number of seconds after being parsed
class Puppet::Settings::DurationSetting < Puppet::Settings::BaseSetting
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
    :duration
  end

  # Convert the value to an integer, parsing numeric string with units if necessary.
  def munge(value)
    case
    when value.is_a?(Integer) || value.nil?
      value
    when (value.is_a?(String) and value =~ FORMAT)
      $1.to_i * UNITMAP[$2 || 's']
    else
      raise Puppet::Settings::ValidationError, "Invalid duration format '#{value.inspect}' for parameter: #{@name}"
    end
  end
end
