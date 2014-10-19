# Configures the Puppet Service Programming Inteterface SPI, by registering extension points
# and default implementations.
#
# See the respective configured services for more information.
#
# @api private
#

module Puppet::Spi::Configuration
    # TODO: This should always be true in Puppet 4.0 (the way it is done now does not allow toggling)
    return unless ::Puppet[:binder] || ::Puppet[:parser] == 'future'
    require 'puppet/spi/binding_schemes'
    require 'puppet/spi/syntax_checkers'

    # Extension-points are registered here:
    #
    # - If in a Ruby submodule it is best to create it here
    # - The class does not have to be required; it will be auto required when the binder
    #   needs it.
    # - If the extension is a multibind, it can be registered here; either with a required
    #   class or a class reference in string form.

    checkers_name = Puppet::Spi::SyntaxCheckers::SPI_SYNTAX_CHECKERS
    checkers_type = Puppet::Spi::SyntaxCheckers::SYNTAX_CHECKERS_TYPE

    schemes_name = Puppet::Spi::BindingSchemes::SPI_BINDINGS_SCHEMES
    schemes_type = Puppet::Spi::BindingSchemes::BINDINGS_SCHEMES_TYPE

    # Register extension points
    # -------------------------
    system_bindings = ::Puppet::Pops::Binder::SystemBindings
    extensions = system_bindings.extensions()

    extensions.multibind(checkers_name).name(checkers_name).hash_of(checkers_type)
    extensions.multibind(schemes_name).name(schemes_name).hash_of(schemes_type)

    # Register injector boot bindings
    # -------------------------------
    boot_bindings = system_bindings.injector_boot_bindings()

    # Register the default bindings scheme handlers
    { 'module'        => 'ModuleScheme', 
      'confdir'       => 'ConfdirScheme',
    }.each do |scheme, class_name|
      boot_bindings \
        .bind.name(scheme) \
        .instance_of(schemes_type) \
        .in_multibind(schemes_name) \
        .to_instance("Puppet::Pops::Binder::SchemeHandler::#{class_name}")
    end

    # Default extensions delivered in Puppet Core are included here
    # -------------------------------------------------------------
    # Classes in this name-space are lazily loaded as they may be overridden and/or never used
    # (Lazy loading is done by binding to the name of a class instead of a Class instance).

    # Register extensions
    # -------------------
    bindings = system_bindings.default_bindings()
    bindings.bind do
      name('json')
      instance_of(checkers_type)
      in_multibind(checkers_name)
      to_instance('Puppet::SyntaxCheckers::Json')
    end

end