module SemanticPuppet
  locales_path = File.absolute_path('../locales', File.dirname(__FILE__))
  # Only create a translation repository of the relevant translations exist
  if Puppet::FileSystem.exist?(File.join(locales_path, Puppet::GettextConfig.current_locale))
    Puppet::GettextConfig.load_translations('semantic_puppet', locales_path, :po)
  end

  autoload :Version, 'semantic_puppet/version'
  autoload :VersionRange, 'semantic_puppet/version_range'
  autoload :Dependency, 'semantic_puppet/dependency'
end
