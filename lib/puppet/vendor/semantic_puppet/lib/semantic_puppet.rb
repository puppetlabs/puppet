module SemanticPuppet
  Puppet::GettextConfig.initialize(File.absolute_path('../locales', File.dirname(__FILE__)), :po)

  autoload :Version, 'semantic_puppet/version'
  autoload :VersionRange, 'semantic_puppet/version_range'
  autoload :Dependency, 'semantic_puppet/dependency'
end
