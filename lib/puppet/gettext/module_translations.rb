require 'puppet/gettext/config'

module Puppet::ModuleTranslations
  def self.from_modulepath(modules)
    modules.each do |mod|
      return unless mod.forge_name

      module_name = mod.forge_name.gsub('/', '-')
      if Puppet::GettextConfig.load_translations(module_name, mod.locale_directory, :po)
        Puppet.debug "Loaded translations for #{module_name}."
      elsif Puppet::GettextConfig.gettext_loaded?
        Puppet.debug "Could not find translation files for #{module_name} at #{mod.locale_directory}. Skipping i18n initialization."
      else
        Puppet.warn_once(:gettext_missing, "No gettext library found, skipping i18n initialization.")
      end
    end
  end

  def self.from_vardir(vardir)
    locale = Puppet::GettextConfig.current_locale
    Dir.glob("#{vardir}/locales/#{locale}/*.po") do |f|
      module_name = File.basename(f, ".po")
      if Puppet::GettextConfig.load_translations(module_name, File.join(vardir, "locales"), :po)
        Puppet.debug "Loaded translations for #{module_name}."
      else
        Puppet.debug "Could not load translations for #{module_name}."
      end
    end
  end
end
