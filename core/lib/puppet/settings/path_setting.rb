class Puppet::Settings::PathSetting < Puppet::Settings::StringSetting
  def munge(value)
    if value.is_a?(String)
      value = value.split(File::PATH_SEPARATOR).map { |d| File.expand_path(d) }.join(File::PATH_SEPARATOR)
    end
    value
  end
end
