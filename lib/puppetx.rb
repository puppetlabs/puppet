# The Puppet Extensions Module
# Submodules of this module should be named after the publisher (e.g. 'user' part of a Puppet Module name).
# The submodule `Puppetx::Puppet` contains the puppet extension points.
#
module Puppetx

  SYNTAX_CHECKERS = 'puppetx::puppet::syntaxcheckers'
  SYNTAX_CHECKERS_TYPE = 'Puppetx::Puppet::SyntaxChecker'

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
      bindings.
        bind_in_multibind(SYNTAX_CHECKERS ).name('json').
        instance_of(SYNTAX_CHECKERS_TYPE).
        to_instance('Puppetx::Puppetlabs::SyntaxCheckers::Json')
    end
  end
end