require 'puppet/util/json'
require 'puppet/module_tool/checksums'

module Puppet::ModuleTool
  module Applications
    class Checksummer < Application

      def initialize(path, options = {})
        @path = Pathname.new(path)
        super(options)
      end

      def run
        changes = []
        sums = Puppet::ModuleTool::Checksums.new(@path)
        checksums.each do |child_path, canonical_checksum|

          # Avoid checksumming the checksums.json file
          next if File.basename(child_path) == "checksums.json"

          path = @path + child_path
          unless path.exist? && canonical_checksum == sums.checksum(path)
            changes << child_path
          end
        end

        # Return an Array of strings representing file paths of files that have
        # been modified since this module was installed. All paths are relative
        # to the installed module directory. This return value is used by the
        # module_tool face changes action, and displayed on the console.
        #
        # Example return value:
        #
        #   [ "REVISION", "manifests/init.pp"]
        #
        changes
      end

      private

      def checksums
        if checksums_file.exist?
          Puppet::Util::Json.load(checksums_file.read)
        elsif metadata_file.exist?
          # Check metadata.json too; legacy modules store their checksums there.
          Puppet::Util::Json.load(metadata_file.read)['checksums'] or
          raise ArgumentError, _("No file containing checksums found.")
        else
          raise ArgumentError, _("No file containing checksums found.")
        end
      end

      def metadata_file
        @path + 'metadata.json'
      end

      def checksums_file
        @path + 'checksums.json'
      end
    end
  end
end
