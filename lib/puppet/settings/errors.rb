# frozen_string_literal: true

# Exceptions for the settings module
require_relative '../../puppet/error'

class Puppet::Settings
  class SettingsError < Puppet::Error; end
  class ValidationError < SettingsError; end
  class InterpolationError < SettingsError; end

  class ParseError < SettingsError
    include Puppet::ExternalFileError
  end
end
