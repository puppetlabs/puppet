require 'puppet/util/settings/file_setting'

class Puppet::Util::Settings::DirectorySetting < Puppet::Util::Settings::FileSetting
  def type
    return :directory
  end
end