class Puppet::Settings::StringSetting < Puppet::Settings::BaseSetting
  def type
    :string
  end

  def validate(value)
    value.nil? || value.is_a?(String)
  end
end
