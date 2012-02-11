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
        cached_paths = @forge.get_release_packages(@install_params)

        cached_paths.each do |cache_path|
          Unpacker.run(cache_path, options)
        end

        cached_paths
      end
    end
  end
end
