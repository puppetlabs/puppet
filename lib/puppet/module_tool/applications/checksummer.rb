require 'puppet/module_tool/checksums'

module Puppet::Module::Tool
  module Applications
    class Checksummer < Application

      def initialize(path, options = {})
        @path = Pathname.new(path)
        super(options)
      end

      def run
        changes = []
        if metadata_file.exist?
          sums = Puppet::Module::Tool::Checksums.new(@path)
          (metadata['checksums'] || {}).each do |child_path, canonical_checksum|
            path = @path + child_path
            if canonical_checksum != sums.checksum(path)
              changes << child_path
            end
          end
        else
          raise ArgumentError, "No metadata.json found."
        end

        # Return an Array of strings representing file paths of files that have
        # been modified since this module was installed. All paths are relative
        # to the installed module directory. This return value is used by the
        # module_tool face changes action, and displayed on the console.
        #
        # Example return value:
        #
        #   [ "REVISION", "metadata.json", "manifests/init.pp"]
        #
        changes
      end

      private

      def metadata
        PSON.parse(metadata_file.read)
      end

      def metadata_file
        (@path + 'metadata.json')
      end
    end
  end
end
