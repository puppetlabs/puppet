# Configures the Puppet Plugins, by registering extension points
# and default implementations.
#
# See the respective configured services for more information.
#
# @api private
#
module Puppet::Plugins
  module Configuration
    require 'puppet/plugins/syntax_checkers'
    require 'puppet/syntax_checkers/base64'
    require 'puppet/syntax_checkers/json'

    # Extension-points are registered here:
    #
    # - If in a Ruby submodule it is best to create it here
    # - The class does not have to be required; it will be auto required when the binder
    #   needs it.
    # - If the extension is a multibind, it can be registered here; either with a required
    #   class or a class reference in string form.

    schemes_name = Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_KEY
    schemes_type = Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_TYPE

    # Register extension points
    # -------------------------
    system_bindings = ::Puppet::Pops::Binder::SystemBindings
    system_bindings.extensions().multibind(schemes_name).name(schemes_name).hash_of(schemes_type)

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

    def self.load_plugins
      # Register extensions
      # -------------------
      {
        SyntaxCheckers::SYNTAX_CHECKERS_KEY => {
          'json' => Puppet::SyntaxCheckers::Json.new,
          'base64' => Puppet::SyntaxCheckers::Base64.new
        }
      }
    end
  end
end