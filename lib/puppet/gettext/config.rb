require 'puppet/util/platform'

module Puppet::GettextConfig
  LOCAL_PATH = File.absolute_path('../../../locales', File.dirname(__FILE__))
  POSIX_PATH = File.absolute_path('../../../../../share/locale', File.dirname(__FILE__))
  WINDOWS_PATH = File.absolute_path('../../../../../../../puppet/share/locale', File.dirname(__FILE__))

  # Search for puppet gettext config files
  # @return [String] path to the config, or nil if not found
  def self.puppet_locale_path
    if File.exist?(LOCAL_PATH)
      return LOCAL_PATH
    elsif Puppet::Util::Platform.windows? && File.exist?(WINDOWS_PATH)
      return WINDOWS_PATH
    elsif !Puppet::Util::Platform.windows? && File.exist?(POSIX_PATH)
      return POSIX_PATH
    else
      nil
    end
  end

  # Determine which translation file format to use
  # @param conf_path [String] the path to the gettext config file
  # @return [Symbol] :mo if in a package structure, :po otherwise
  def self.translation_mode(conf_path)
    if WINDOWS_PATH == conf_path || POSIX_PATH == conf_path
      return :mo
    else
      return :po
    end
  end

  # Attempt to initialize the gettext-setup gem
  # @param path [String] to gettext config file
  # @param file_format [Symbol] translation file format to use, either :po or :mo
  # @return true if initialization succeeded, false otherwise
  def self.initialize(conf_file_location, file_format)
    # Bypass gettext until we can resolve a performance regression related to it, PUP-8009.
    return false
  end
end
