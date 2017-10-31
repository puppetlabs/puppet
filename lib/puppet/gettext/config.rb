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
  # Whether translations have been loaded for a given project
  # @param project_name [String] the project whose translations we are querying
  # @return [Boolean] true if translations have been loaded for the project
  def self.translations_loaded?(project_name)
    return false unless gettext_loaded?
    if @loaded_repositories[project_name]
      return true
    else
      return false
    end
  end

  # @api private
  # Creates a new empty text domain with the given name, replacing
  # any existing domain with that name, then switches to using
  # that domain. Also clears the cache of loaded translations.
  # @param domain_name [String] the name of the domain to create
  def self.create_text_domain(domain_name)
    return unless gettext_loaded?
    # Clear the cache of loaded translation repositories
    @loaded_repositories = {}
    FastGettext.add_text_domain(domain_name, type: :chain, chain: [])
    #TODO remove this when we start managing domains per environment
    FastGettext.default_text_domain = domain_name
    FastGettext.text_domain = domain_name
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
  # @param conf_path [String] the path to the gettext config file
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
  # Attempt to load tranlstions for the given project.
  # @param project_name [String] the project whose translations we want to load
  # @param locale_dir [String] the path to the directory containing translations
  # @param file_format [Symbol] translation file format to use, either :po or :mo
  # @return true if initialization succeeded, false otherwise
  def self.load_translations(project_name, locale_dir, file_format)
    return false if @gettext_disabled || !@gettext_loaded

    return false unless locale_dir && Puppet::FileSystem.exist?(locale_dir)

    unless file_format == :po || file_format == :mo
      raise Puppet::Error, "Unsupported translation file format #{file_format}; please use :po or :mo"
    end

    if project_name.nil? || project_name.empty?
      raise Puppet::Error, "A project name must be specified in order to initialize translations."
    end

    add_repository_to_domain(project_name, locale_dir, file_format)
    return true
  end

  # @api private
  # Add the translations for this project to the domain's repository chain
  # chain for the currently selected text domain, if needed.
  # @param project_name [String] the name of the project for which to load translations
  # @param locale_dir [String] the path to the directory containing translations
  # @param file_format [Symbol] the fomat of the translations files, :po or :mo
  def self.add_repository_to_domain(project_name, locale_dir, file_format)
    # check if we've already loaded these transltaions
    current_chain = FastGettext.translation_repositories[FastGettext.text_domain].chain
    return current_chain if @loaded_repositories[project_name]

    repository = FastGettext::TranslationRepository.build(project_name,
                                                          path: locale_dir,
                                                          type: file_format,
                                                          ignore_fuzzy: false)
    @loaded_repositories[project_name] = true
    current_chain << repository
  end

  # @api private
  # Sets the language in which to display strings.
  # @param locale [String] the language portion of a locale string (e.g. "ja")
  def self.set_locale(locale)
    return if !gettext_loaded?
    # make sure we're not using the `available_locales` machinery
    FastGettext.default_available_locales = nil

    FastGettext.default_locale = locale
  end
end
