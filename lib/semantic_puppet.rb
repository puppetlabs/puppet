begin
  require 'gettext-setup'
rescue LoadError
  def _(msg)
    msg
  end
end

module SemanticPuppet
  if defined?(GettextSetup)
    GettextSetup.initialize(File.absolute_path('semantic_puppet/locales', File.dirname(__FILE__)))
  end

  autoload :Version, 'semantic_puppet/version'
  autoload :VersionRange, 'semantic_puppet/version_range'
  autoload :Dependency, 'semantic_puppet/dependency'
end
