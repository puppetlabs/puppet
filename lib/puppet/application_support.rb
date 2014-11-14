require 'yaml'

require 'puppet'
require 'puppet/node/environment'
require 'puppet/file_system'
require 'puppet/indirector'

module Puppet
  module ApplicationSupport

    # Pushes a Puppet Context configured with a remote environment for an agent
    # (one that exists at the master end), and a regular environment for other
    # modes. The configuration is overridden with options from the command line
    # before being set in a pushed Puppet Context.
    #
    # @param run_mode [Puppet::Util::RunMode] Puppet's current Run Mode.
    # @return [void]
    # @api private
    def self.push_application_context(run_mode)
      Puppet.push_context(Puppet.base_context(Puppet.settings), "Update for application settings (#{run_mode})")
      # This use of configured environment is correct, this is used to establish
      # the defaults for an application that does not override, or where an override
      # has not been made from the command line.
      #
      configured_environment_name = Puppet[:environment]
      if run_mode.name == :agent
        configured_environment = Puppet::Node::Environment.remote(configured_environment_name)
      else
        configured_environment = Puppet.lookup(:environments).get!(configured_environment_name)
      end
      configured_environment = configured_environment.override_from_commandline(Puppet.settings)

      # Setup a new context using the app's configuration
      Puppet.push_context({:current_environment => configured_environment},
                          "Update current environment from application's configuration")
    end

    # Reads the routes YAML settings from the file specified by Puppet[:route_file]
    # and resets indirector terminii for the current application class if listed.
    #
    # For instance, PE uses this to set the master facts terminus
    # to 'puppetdb' and its cache terminus to 'yaml'.
    #
    # @param application_name [String] The name of the current application.
    # @return [void]
    # @api private
    def self.configure_indirector_routes(application_name)
      route_file = Puppet[:route_file]
      if Puppet::FileSystem.exist?(route_file)
        routes = YAML.load_file(route_file)
        application_routes = routes[application_name]
        Puppet::Indirector.configure_routes(application_routes) if application_routes
      end
    end

  end
end
