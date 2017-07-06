class Puppet::Settings::ArraySetting < Puppet::Settings::BaseSetting

  def type
    :array
  end

  def munge(value)
    case value
    when String
      value.split(/\s*,\s*/)
    when Array
      value
    else
      raise ArgumentError, "Expected an Array or String, got a #{value.class}"
    end
  end
end
