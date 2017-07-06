require 'net/http'
require 'semver'
require 'json'
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
          errors = JSON.parse(response.body)['error'] rescue "HTTP #{response.code}, #{response.body}"
          Puppet.warning "#{failure} (#{errors})"
        end
      end

      def metadata(require_metadata = false)
        return @metadata if @metadata
        @metadata = Puppet::ModuleTool::Metadata.new

        unless @path
          raise ArgumentError, "Could not determine module path"
        end

        if require_metadata && !Puppet::ModuleTool.is_module_root?(@path)
          raise ArgumentError, "Unable to find metadata.json in module root at #{@path} See https://docs.puppet.com/puppet/latest/reference/modules_publishing.html for required file format."
        end

        metadata_path   = File.join(@path, 'metadata.json')

        if File.file?(metadata_path)
          File.open(metadata_path) do |f|
            begin
              @metadata.update(JSON.load(f))
            rescue JSON::ParserError => ex
              raise ArgumentError, "Could not parse JSON #{metadata_path}", ex.backtrace
            end
          end
        end

        if File.file?(File.join(@path, 'Modulefile'))
          Puppet.warning "A Modulefile was found in the root directory of the module. This file will be ignored and can safely be removed."
        end

        return @metadata
      end

      def load_metadata!
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
