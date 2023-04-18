# frozen_string_literal: true
class Puppet::Settings::PortSetting < Puppet::Settings::IntegerSetting
  def munge(value)
    value = super

    if value < 0 || value > 65535
      raise Puppet::Settings::ValidationError, _("Value '%{value}' is not a valid port number for parameter: %{name}") % { value: value.inspect, name: @name }
    end

    value
  end

  def type
    :port
  end
end
