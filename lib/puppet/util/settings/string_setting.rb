# The base element type.
require 'puppet/util/settings/base_setting'

class Puppet::Util::Settings::StringSetting < Puppet::Util::Settings::BaseSetting
  def type
    :string
  end

  def validate(value)
    value.nil? or value.is_a?(String)
  end
end
