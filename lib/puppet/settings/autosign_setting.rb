require 'puppet/settings/base_setting'

# A specialization of the file setting to allow boolean values.
#
# The autosign value can be either a boolean or a file path, and if the setting
# is a file path then it may have a owner/group/mode specified.
#
# @api private
class Puppet::Settings::AutosignSetting < Puppet::Settings::FileSetting

  def munge(value)
    if ['true', true].include? value
      true
    elsif ['false', false, nil].include? value
      false
    elsif Puppet::Util.absolute_path?(value)
      value
    else
      raise Puppet::Settings::ValidationError, _("Invalid autosign value %{value}: must be 'true'/'false' or an absolute path") % { value: value }
    end
  end
end
