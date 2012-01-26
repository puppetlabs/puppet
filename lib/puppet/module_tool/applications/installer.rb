require 'open-uri'
require 'pathname'
require 'tmpdir'

module Puppet::Module::Tool
  module Applications
    class Installer < Application

      def initialize(name, options = {})
        @forge = Puppet::Forge::Forge.new
        @install_params = {}

        if File.exist?(name)
          if File.directory?(name)
            # TODO Unify this handling with that of Unpacker#check_clobber!
            raise ArgumentError, "Module already installed: #{name}"
          end
          @filename = File.expand_path(name)
          @install_params[:source] = :filesystem
          @install_params[:filename] = @filename
          parse_filename!
        else
          @install_params[:source] = :repository
          begin
            @install_params[:author], @install_params[:modname] = Puppet::Module::Tool::username_and_modname_from(name)
          rescue ArgumentError
            raise "Could not install module with invalid name: #{name}"
          end
          @install_params[:version_requirement] = options[:version]
        end
        super(options)
      end

      def force?
        options[:force]
      end

      def run
        cache_path = @forge.get_release_package(@install_params)

        module_dir = Unpacker.run(cache_path, options)
        # Return the Pathname object representing the path to the installed
        # module. This return value is used by the module_tool face install
        # action, and displayed to on the console.
        #
        # Example return value:
        #
        #   "/etc/puppet/modules/apache"
        #
        module_dir
      end
    end
  end
end
