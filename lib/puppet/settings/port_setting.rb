# frozen_string_literal: true

class Puppet::Settings::PortSetting < Puppet::Settings::IntegerSetting
  def munge(value)
    value = super(value)

    if value < 0 || value > 65_535
      raise Puppet::Settings::ValidationError, _("Value '%{value}' is not a valid port number for parameter: %{name}") % { value: value.inspect, name: @name }
    end

    value
  end

  def type
    :port
  end
end
