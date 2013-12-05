require 'puppet/settings/base_setting'

class Puppet::Settings::AutosignSetting < Puppet::Settings::BaseSetting

  def type
    :autosign
  end

  def munge(value)
    if ['true', true].include? value
      true
    elsif ['false', false, nil].include? value
      false
    elsif Puppet::Util.absolute_path?(value)
      value
    else
      raise Puppet::Settings::ValidationError, "Invalid autosign value #{value}: must be 'true'/'false' or an absolute path"
    end
  end
end
