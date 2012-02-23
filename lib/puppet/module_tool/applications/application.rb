require 'net/http'
require 'semver'
require 'puppet/module_tool/utils/interrogation'

module Puppet::Module::Tool
  module Applications
    class Application
      include Puppet::Module::Tool::Utils::Interrogation

      def self.run(*args)
        new(*args).run
      end

      attr_accessor :options

      def initialize(options = {})
        @options = options
      end

      def run
        raise NotImplementedError, "Should be implemented in child classes."
      end

      def discuss(response, success, failure)
        case response
        when Net::HTTPOK, Net::HTTPCreated
          Puppet.notice success
        else
          errors = PSON.parse(response.body)['error'] rescue "HTTP #{response.code}, #{response.body}"
          Puppet.warning "#{failure} (#{errors})"
        end
      end

      def metadata(require_modulefile = false)
        unless @metadata
          unless @path
            raise ArgumentError, "Could not determine module path"
          end
          @metadata = Puppet::Module::Tool::Metadata.new
          contents = ContentsDescription.new(@path)
          contents.annotate(@metadata)
          checksums = Checksums.new(@path)
          checksums.annotate(@metadata)
          modulefile_path = File.join(@path, 'Modulefile')
          if File.file?(modulefile_path)
            Puppet::Module::Tool::ModulefileReader.evaluate(@metadata, modulefile_path)
          elsif require_modulefile
            raise ArgumentError, "No Modulefile found."
          end
        end
        @metadata
      end

      def load_modulefile!
        @metadata = nil
        metadata(true)
      end

      # Use to extract and validate a module name and version from a
      # filename
      # Note: Must have @filename set to use this
      def parse_filename!
        @release_name = File.basename(@filename,'.tar.gz')
        match = /^(.*?)-(.*?)-(\d+\.\d+\.\d+.*?)$/.match(@release_name)
        if match then
          @username, @module_name, @version = match.captures
        else
          raise ArgumentError, "Could not parse filename to obtain the username, module name and version.  (#{@release_name})"
        end
        @full_module_name = [@username, @module_name].join('-')
        unless @username && @module_name
          raise ArgumentError, "Username and Module name not provided"
        end
        unless SemVer.valid?(@version)
          raise ArgumentError, "Invalid version format: #{@version} (Semantic Versions are acceptable: http://semver.org)"
        end
      end
    end
  end
end
