class Puppet::Settings::EnumSetting < Puppet::Settings::BaseSetting
  attr_accessor :values

  def type
    :enum
  end

  def munge(value)
    if values.include?(value)
      value
    else
      raise Puppet::Settings::ValidationError,
        _("Invalid value '%{value}' for parameter %{name}. Allowed values are '%{allowed_values}'") % { value: value, name: @name, allowed_values: values.join("', '") }
    end
  end
end
