require 'puppet/settings/file_setting'

class Puppet::Settings::DirectorySetting < Puppet::Settings::FileSetting
  def type
    :directory
  end
end
