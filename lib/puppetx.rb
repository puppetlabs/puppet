# The Puppet Extensions Module.
#
# Submodules of this module should be named after the publisher (e.g. 'user' part of a Puppet Module name).
# The submodule {Puppetx::Puppet} contains the puppet extension points.
#
# This module also contains constants that are used when defining extensions.
#
# @api public
#
module Puppetx

  # The lookup **key** for the multibind containing syntax checkers used to syntax check embedded string in non
  # puppet DSL syntax.
  # @api public
  SYNTAX_CHECKERS       = 'puppetx::puppet::syntaxcheckers'

  # The lookup **type** for the multibind containing syntax checkers used to syntax check embedded string in non
  # puppet DSL syntax.
  # @api public
  SYNTAX_CHECKERS_TYPE  = 'Puppetx::Puppet::SyntaxChecker'

  # The lookup **key** for the multibind containing a map from scheme name to scheme handler class for bindings schemes.
  # @api public
  BINDINGS_SCHEMES      = 'puppetx::puppet::bindings::schemes'

  # The lookup **type** for the multibind containing a map from scheme name to scheme handler class for bindings schemes.
  # @api public
  BINDINGS_SCHEMES_TYPE = 'Puppetx::Puppet::BindingsSchemeHandler'

  # This module is the name space for extension points
  # @api public
  module Puppet

    if ::Puppet[:binder] || ::Puppet.future_parser?
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

        # Register injector boot bindings
        # -------------------------------
        boot_bindings = system_bindings.injector_boot_bindings()

        # Register the default bindings scheme handlers
        require 'puppetx/puppet/bindings_scheme_handler'
        { 'module'        => 'ModuleScheme', 
          'confdir'       => 'ConfdirScheme',
        }.each do |scheme, class_name|
          boot_bindings.bind.name(scheme).instance_of(BINDINGS_SCHEMES_TYPE).in_multibind(BINDINGS_SCHEMES).
            to_instance("Puppet::Pops::Binder::SchemeHandler::#{class_name}")
        end
      end
  end

  # Module with implementations of various extensions
  # @api public
  module Puppetlabs
    # Default extensions delivered in Puppet Core are included here

    # @api public
    module SyntaxCheckers
      if ::Puppet[:binder] || ::Puppet.future_parser?

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
end
