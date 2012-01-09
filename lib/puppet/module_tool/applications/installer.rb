require 'open-uri'
require 'pathname'
require 'tmpdir'

module Puppet::Module::Tool
  module Applications
    class Installer < Application

      def initialize(name, options = {})
        if File.exist?(name)
          if File.directory?(name)
            # TODO Unify this handling with that of Unpacker#check_clobber!
            raise ArgumentError, "Module already installed: #{name}"
          end
          @source = :filesystem
          @filename = File.expand_path(name)
          parse_filename!
        else
          @source = :repository
          begin
            @username, @module_name = Puppet::Module::Tool::username_and_modname_from(name)
          rescue ArgumentError
            raise "Could not install module with invalid name: #{name}"
          end
          @version_requirement = options[:version]
        end
        super(options)
      end

      def force?
        options[:force]
      end

      def run
        case @source
        when :repository
          if match['file']
            begin
              cache_path = repository.retrieve(match['file'])
            rescue OpenURI::HTTPError => e
              raise RuntimeError, "Could not install module: #{e.message}"
            end
            module_dir = Unpacker.run(cache_path, options)
          else
            raise RuntimeError, "Malformed response from module repository."
          end
        when :filesystem
          repository = Repository.new('file:///')
          uri = URI.parse("file://#{URI.escape(File.expand_path(@filename))}")
          cache_path = repository.retrieve(uri)
          module_dir = Unpacker.run(cache_path, options)
        else
          raise ArgumentError, "Could not determine installation source"
        end

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

      private

      def match
        return @match ||= begin
          url = repository.uri + "/users/#{@username}/modules/#{@module_name}/releases/find.json"
          if @version_requirement
            url.query = "version=#{URI.escape(@version_requirement)}"
          end
          begin
            raw_result = read_match(url)
          rescue => e
            raise ArgumentError, "Could not find a release for this module (#{e.message})"
          end
          @match = PSON.parse(raw_result)
        end
      end

      def read_match(url)
        return url.read
      end
    end
  end
end
