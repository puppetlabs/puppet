require 'puppet/gettext/config'

module Puppet::ModuleTranslations

  # @api private
  # Loads translation files for each of the specified modules,
  # if present. Requires the modules to have `forge_name` specified.
  # @param [[Module]] modules a list of modules for which to
  #        load translations
  def self.load_from_modulepath(modules)
    modules.each do |mod|
      next unless mod.forge_name && mod.has_translations?(Puppet::GettextConfig.current_locale)

      module_name = mod.forge_name.gsub('/', '-')
      if Puppet::GettextConfig.load_translations(module_name, mod.locale_directory, :po)
        Puppet.debug "Loaded translations for #{module_name}."
      elsif Puppet::GettextConfig.gettext_loaded?
        Puppet.debug "Could not find translation files for #{module_name} at #{mod.locale_directory}. Skipping translation initialization."
      else
        Puppet.warn_once("gettext_unavailable", "gettext_unavailable", "No gettext library found, skipping translation initialization.")
      end
    end
  end

  # @api private
  # Loads translation files that have been pluginsync'd for modules
  # from the $vardir.
  # @param [String] vardir the path to Puppet's vardir
  def self.load_from_vardir(vardir)
    locale = Puppet::GettextConfig.current_locale
    Dir.glob("#{vardir}/locales/#{locale}/*.po") do |f|
      module_name = File.basename(f, ".po")
      if Puppet::GettextConfig.load_translations(module_name, File.join(vardir, "locales"), :po)
        Puppet.debug "Loaded translations for #{module_name}."
      elsif Puppet::GettextConfig.gettext_loaded?
        Puppet.debug "Could not load translations for #{module_name}."
      else
        Puppet.warn_once("gettext_unavailable", "gettext_unavailable", "No gettext library found, skipping translation initialization.")
      end
    end
  end
end
