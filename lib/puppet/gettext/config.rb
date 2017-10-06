require 'puppet/util/platform'
require 'puppet/file_system'

module Puppet::GettextConfig
  LOCAL_PATH = File.absolute_path('../../../locales', File.dirname(__FILE__))
  POSIX_PATH = File.absolute_path('../../../../../share/locale', File.dirname(__FILE__))
  WINDOWS_PATH = File.absolute_path('../../../../../../../puppet/share/locale', File.dirname(__FILE__))

  # Load gettext helpers and track whether they're available.
  # Used instead of features because we initialize gettext before features is available.
  # Stubbing gettext if unavailable is handled in puppet.rb.
  begin
    require 'gettext-setup'
    require 'locale'
    @gettext_loaded = true
  rescue LoadError
    @gettext_loaded = false
  end

  # Whether we were able to require gettext-setup and locale
  # @return [Boolean] true if gettext-setup was successfully loaded
  def self.gettext_loaded?
    @gettext_loaded
  end

  # Search for puppet gettext config files
  # @return [String] path to the config, or nil if not found
  def self.puppet_locale_path
    if Puppet::FileSystem.exist?(LOCAL_PATH)
      return LOCAL_PATH
    elsif Puppet::Util::Platform.windows? && Puppet::FileSystem.exist?(WINDOWS_PATH)
      return WINDOWS_PATH
    elsif !Puppet::Util::Platform.windows? && Puppet::FileSystem.exist?(POSIX_PATH)
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

  # Prevent future gettext initializations
  def self.disable_gettext
    @gettext_disabled = true
  end

  # Attempt to initialize the gettext-setup gem
  # @param path [String] to gettext config file
  # @param file_format [Symbol] translation file format to use, either :po or :mo
  # @return true if initialization succeeded, false otherwise
  def self.initialize(conf_file_dir, file_format)
    return false if @gettext_disabled || !@gettext_loaded

    unless file_format == :po || file_format == :mo
      raise Puppet::Error, "Unsupported translation file format #{file_format}; please use :po or :mo"
    end

    return false if conf_file_dir.nil?

    conf_file = File.join(conf_file_dir, "config.yaml")
    if Puppet::FileSystem.exist?(conf_file)
      if GettextSetup.method(:initialize).parameters.count == 1
        # For use with old gettext-setup gem versions, will load PO files only
        GettextSetup.initialize(conf_file_dir)
      else
        GettextSetup.initialize(conf_file_dir, :file_format => file_format)
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
  end
end
