# Exceptions for the settings module

class Puppet::Util::Settings
  class SettingsError < Puppet::Error ; end
  class ValidationError < SettingsError ; end
  class InterpolationError < SettingsError ; end
end
