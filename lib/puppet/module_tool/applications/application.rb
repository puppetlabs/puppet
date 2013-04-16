require 'net/http'
require 'semver'
require 'puppet/util/colors'

module Puppet::ModuleTool
  module Applications
    class Application
      include Puppet::Util::Colors

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
          @metadata = Puppet::ModuleTool::Metadata.new
          contents = ContentsDescription.new(@path)
          contents.annotate(@metadata)
          checksums = Checksums.new(@path)
          checksums.annotate(@metadata)
          modulefile_path = File.join(@path, 'Modulefile')
          if File.file?(modulefile_path)
            Puppet::ModuleTool::ModulefileReader.evaluate(@metadata, modulefile_path)
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

      def parse_filename(filename)
        if match = /^((.*?)-(.*?))-(\d+\.\d+\.\d+.*?)$/.match(File.basename(filename,'.tar.gz'))
          module_name, author, shortname, version = match.captures
        else
          raise ArgumentError, "Could not parse filename to obtain the username, module name and version.  (#{@release_name})"
        end

        unless SemVer.valid?(version)
          raise ArgumentError, "Invalid version format: #{version} (Semantic Versions are acceptable: http://semver.org)"
        end

        return {
          :module_name => module_name,
          :author      => author,
          :dir_name    => shortname,
          :version     => version
        }
      end
    end
  end
end
