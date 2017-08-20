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

  def self.module_initialized?(module_name)
    begin
      GettextSetup.translation_repositories.has_key? module_name
    rescue NameError
      # If GettextSetup has not been loaded yet, just return false
      false
    end
  end

  # Attempt to initialize the gettext-setup gem
  # @param path [String] to gettext config file
  # @param file_format [Symbol] translation file format to use, either :po or :mo
  # @return true if initialization succeeded, false otherwise
  def self.initialize(conf_file_location, file_format)
    unless file_format == :po || file_format == :mo
      raise Puppet::Error, "Unsupported translation file format #{file_format}; please use :po or :mo"
    end

    begin
      require 'gettext-setup'
      require 'locale'

      if conf_file_location && File.exists?(conf_file_location)
        if GettextSetup.method(:initialize).parameters.count == 1
          # For use with old gettext-setup gem versions, will load PO files only
          GettextSetup.initialize(conf_file_location)
        else
          GettextSetup.initialize(conf_file_location, :file_format => file_format)
        end
        # Only change this once.
        # Because negotiate_locales will only return a non-default locale if
        # the system locale matches a translation set actually available for the
        # given gettext project, we don't want this to get set back to default if
        # we load a module that doesn't have translations, but Puppet does have
        # translations for the user's locale.
        if FastGettext.locale == GettextSetup.default_locale
          FastGettext.locale = GettextSetup.negotiate_locale(Locale.current.language)
        end
        true
      else
        false
      end
    rescue LoadError
      false
    end
  end
end
