require 'puppet/util/platform'
require 'puppet/file_system'

module Puppet::GettextConfig
  LOCAL_PATH = File.absolute_path('../../../locales', File.dirname(__FILE__))
  POSIX_PATH = File.absolute_path('../../../../../share/locale', File.dirname(__FILE__))
  WINDOWS_PATH = File.absolute_path('../../../../../../../puppet/share/locale', File.dirname(__FILE__))

  DEFAULT_TEXT_DOMAIN = 'default-text-domain'

  # Load gettext helpers and track whether they're available.
  # Used instead of features because we initialize gettext before features is available.
  begin
    require 'fast_gettext'
    require 'locale'

    # Make translation methods (e.g. `_()` and `n_()`) available everywhere.
    class ::Object
      include FastGettext::Translation
    end

    @gettext_loaded = true
  rescue LoadError
    # Stub out gettext's `_` and `n_()` methods, which attempt to load translations,
    # with versions that do nothing
    require 'puppet/gettext/stubs'
    @gettext_loaded = false
  end

  # @api private
  # Whether we were able to require fast_gettext and locale
  # @return [Boolean] true if translation gems were successfully loaded
  def self.gettext_loaded?
    @gettext_loaded
  end

  # @api private
  # Returns the currently selected locale from FastGettext,
  # or 'en' of gettext has not been loaded
  # @return [String] the active locale
  def self.current_locale
    if gettext_loaded?
      return FastGettext.default_locale
    else
      return 'en'
    end
  end

  # @api private
  # Returns a list of the names of the loaded text domains
  # @return [[String]] the names of the loaded text domains
  def self.loaded_text_domains
    return [] if @gettext_disabled || !gettext_loaded?

    return FastGettext.translation_repositories.keys
  end

  # @api private
  # Clears the translation repository for the given text domain,
  # creating it if it doesn't exist, then adds default translations
  # and switches to using this domain.
  # @param [String] domain_name the name of the domain to create
  def self.reset_text_domain(domain_name)
    return if @gettext_disabled || !gettext_loaded?

    FastGettext.add_text_domain(domain_name,
                                type: :chain,
                                chain: [],
                                report_warning: false)
    copy_default_translations(domain_name)
    FastGettext.text_domain = domain_name
  end

  # @api private
  # Creates a default text domain containing the translations for
  # Puppet as the start of chain. When semantic_puppet gets initialized,
  # its translations are added to this chain. This is used as a cache
  # so that all non-module translations only need to be loaded once as
  # we create and reset environment-specific text domains.
  #
  # @return true if Puppet translations were successfully loaded, false
  # otherwise
  def self.create_default_text_domain
    return if @gettext_disabled || !gettext_loaded?

    FastGettext.add_text_domain(DEFAULT_TEXT_DOMAIN,
                                type: :chain,
                                chain: [],
                                report_warning: false)
    FastGettext.default_text_domain = DEFAULT_TEXT_DOMAIN

    load_translations('puppet', puppet_locale_path, translation_mode(puppet_locale_path), DEFAULT_TEXT_DOMAIN)
  end

  # @api private
  # Switches the active text domain, if the requested domain exists.
  # @param [String] domain_name the name of the domain to switch to
  def self.use_text_domain(domain_name)
    return if @gettext_disabled || !gettext_loaded?

    if FastGettext.translation_repositories.include?(domain_name)
      FastGettext.text_domain = domain_name
    end
  end

  # @api private
  # Delete all text domains.
  def self.delete_all_text_domains
    FastGettext.translation_repositories.clear
    FastGettext.default_text_domain = nil
    FastGettext.text_domain = nil
  end

  # @api private
  # Deletes the text domain with the given name
  # @param [String] domain_name the name of the domain to delete
  def self.delete_text_domain(domain_name)
    return if @gettext_disabled || !gettext_loaded?

    FastGettext.translation_repositories.delete(domain_name)
    if FastGettext.text_domain == domain_name
      FastGettext.text_domain = nil
    end
  end

  # @api private
  # Deletes all text domains except the default one
  def self.delete_environment_text_domains
    return if @gettext_disabled || !gettext_loaded?

    FastGettext.translation_repositories.keys.each do |key|
      # do not clear default translations
      next if key == DEFAULT_TEXT_DOMAIN

      FastGettext.translation_repositories.delete(key)
    end
    FastGettext.text_domain = nil
  end

  # @api private
  # Adds translations from the default text domain to the specified
  # text domain. Creates the default text domain if one does not exist
  # (this will load Puppet's translations).
  #
  # Since we are currently (Nov 2017) vendoring semantic_puppet, in normal
  # flows these translations will be copied along with Puppet's.
  #
  # @param [String] domain_name the name of the domain to add translations to
  def self.copy_default_translations(domain_name)
    return if @gettext_disabled || !gettext_loaded?

    if FastGettext.default_text_domain.nil?
      create_default_text_domain
    end

    puppet_translations = FastGettext.translation_repositories[FastGettext.default_text_domain].chain
    FastGettext.translation_repositories[domain_name].chain.push(*puppet_translations)
  end

  # @api private
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

  # @api private
  # Determine which translation file format to use
  # @param [String] conf_path the path to the gettext config file
  # @return [Symbol] :mo if in a package structure, :po otherwise
  def self.translation_mode(conf_path)
    if WINDOWS_PATH == conf_path || POSIX_PATH == conf_path
      return :mo
    else
      return :po
    end
  end

  # @api private
  # Prevent future gettext initializations
  def self.disable_gettext
    @gettext_disabled = true
  end

  # @api private
  # Attempt to load translations for the given project.
  # @param [String] project_name the project whose translations we want to load
  # @param [String] locale_dir the path to the directory containing translations
  # @param [Symbol] file_format translation file format to use, either :po or :mo
  # @return true if initialization succeeded, false otherwise
  def self.load_translations(project_name, locale_dir, file_format, text_domain = FastGettext.text_domain)
    if project_name.nil? || project_name.empty?
      raise Puppet::Error, "A project name must be specified in order to initialize translations."
    end

    return false if @gettext_disabled || !@gettext_loaded

    return false unless locale_dir && Puppet::FileSystem.exist?(locale_dir)

    unless file_format == :po || file_format == :mo
      raise Puppet::Error, "Unsupported translation file format #{file_format}; please use :po or :mo"
    end

    add_repository_to_domain(project_name, locale_dir, file_format, text_domain)
    return true
  end

  # @api private
  # Add the translations for this project to the domain's repository chain
  # chain for the currently selected text domain, if needed.
  # @param [String] project_name the name of the project for which to load translations
  # @param [String] locale_dir the path to the directory containing translations
  # @param [Symbol] file_format the format of the translations files, :po or :mo
  def self.add_repository_to_domain(project_name, locale_dir, file_format, text_domain = FastGettext.text_domain)
    return if @gettext_disabled || !gettext_loaded?

    current_chain = FastGettext.translation_repositories[text_domain].chain

    repository = FastGettext::TranslationRepository.build(project_name,
                                                          path: locale_dir,
                                                          type: file_format,
                                                          report_warning: false)
    current_chain << repository
  end

  # @api private
  # Sets FastGettext's locale to the current system locale
  def self.setup_locale
    return if @gettext_disabled || !gettext_loaded?

    set_locale(Locale.current.language)
  end

  # @api private
  # Sets the language in which to display strings.
  # @param [String] locale the language portion of a locale string (e.g. "ja")
  def self.set_locale(locale)
    return if @gettext_disabled || !gettext_loaded?
    # make sure we're not using the `available_locales` machinery
    FastGettext.default_available_locales = nil

    FastGettext.default_locale = locale
  end
end
