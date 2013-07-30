# The Puppet Extensions Module
# Submodules of this module should be named after the publisher (e.g. 'user' part of a Puppet Module name).
# The submodule `Puppetx::Puppet` contains the puppet extension points.
#
module Puppetx

  SYNTAX_CHECKERS       = 'puppetx::puppet::syntaxcheckers'
  SYNTAX_CHECKERS_TYPE  = 'Puppetx::Puppet::SyntaxChecker'

  BINDINGS_SCHEMES      = 'puppetx::puppet::bindings::schemes'
  BINDINGS_SCHEMES_TYPE = 'Puppetx::Puppet::BindingsSchemeHandler'

  HIERA2_BACKENDS      = 'puppetx::puppet::hiera2::backends'
  HIERA2_BACKENDS_TYPE = 'Puppetx::Puppet::Hiera2Backend'

  module Puppet

    # Extension-points are registered here:
    # - If in a Ruby submodule it is best to create it here
    # - The class does not have to be required; it will be auto required when the binder
    #   needs it.
    # - If the extension is a multibind, it can be registered here; either with a required
    #   class or a class reference in string form.

    # Register extension points
    # -------------------------
    system_bindings = ::Puppet::Pops::Binder::SystemBindings
    extensions = system_bindings.extensions()
    extensions.multibind(SYNTAX_CHECKERS).name(SYNTAX_CHECKERS).hash_of(SYNTAX_CHECKERS_TYPE)
    extensions.multibind(BINDINGS_SCHEMES).name(BINDINGS_SCHEMES).hash_of(BINDINGS_SCHEMES_TYPE)
    extensions.multibind(HIERA2_BACKENDS).name(HIERA2_BACKENDS).hash_of(HIERA2_BACKENDS_TYPE)

    # Register injector boot bindings
    # -------------------------------
    boot_bindings = system_bindings.injector_boot_bindings()

    # Register the default bindings scheme handlers
    require 'puppetx/puppet/bindings_scheme_handler'
    { 'module'        => 'ModuleScheme', 
      'confdir'       => 'ConfdirScheme',
      'module-hiera'  => 'ModuleHieraScheme',
      'confdir-hiera' => 'ConfdirHieraScheme'
    }.each do |scheme, class_name|
      boot_bindings.bind.name(scheme).instance_of(BINDINGS_SCHEMES_TYPE).in_multibind(BINDINGS_SCHEMES).
        to_instance("Puppet::Pops::Binder::SchemeHandler::#{class_name}")
    end

    # Register the default hiera2 backends
    require 'puppetx/puppet/hiera2_backend'
    { 'json' => 'JsonBackend',
      'yaml' => 'YamlBackend'
    }.each do |symbolic, class_name|
      boot_bindings.bind.name(symbolic).instance_of(HIERA2_BACKENDS_TYPE).in_multibind(HIERA2_BACKENDS).
        to_instance("Puppet::Pops::Binder::Hiera2::#{class_name}")
    end
  end

  # Module with implementations of various extensions
  module Puppetlabs
    # Default extensions delivered in Puppet Core are included here

    module SyntaxCheckers

      # Classes in this name-space are lazily loaded as they may be overridden and/or never used
      # (Lazy loading is done by binding to the name of a class instead of a Class instance).

      # Register extensions
      # -------------------
      system_bindings = ::Puppet::Pops::Binder::SystemBindings
      bindings = system_bindings.default_bindings()
      bindings.bind do
        name('json')
        instance_of(SYNTAX_CHECKERS_TYPE)
        in_multibind(SYNTAX_CHECKERS)
        to_instance('Puppetx::Puppetlabs::SyntaxCheckers::Json')
      end
    end
  end
end