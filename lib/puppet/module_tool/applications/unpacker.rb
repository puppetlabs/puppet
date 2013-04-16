require 'pathname'
require 'tmpdir'

module Puppet::ModuleTool
  module Applications
    class Unpacker < Application

      def initialize(filename, options = {})
        @filename = Pathname.new(filename)
        parsed = parse_filename(filename)
        @module_name = parsed[:module_name]
        super(options)
        @module_dir = Pathname.new(options[:target_dir]) + parsed[:dir_name]
      end

      def run
        extract_module_to_install_dir

        # Return the Pathname object representing the directory where the
        # module release archive was unpacked the to, and the module release
        # name.
        @module_dir
      end

      # Obtain a suitable temporary path for building and unpacking tarballs
      #
      # @return [Pathname] path to temporary build location
      def build_dir
        Puppet::Forge::Cache.base_path + "tmp-unpacker-#{Digest::SHA1.hexdigest(@filename.basename.to_s)}"
      end

      private

      def extract_module_to_install_dir
        delete_existing_installation_or_abort!

        build_dir.mkpath
        begin
          begin
            Puppet::ModuleTool::Tar.instance(@module_name).unpack(@filename.to_s, build_dir.to_s)
          rescue Puppet::ExecutionFailure => e
            raise RuntimeError, "Could not extract contents of module archive: #{e.message}"
          end

          # grab the first directory
          extracted = build_dir.children.detect { |c| c.directory? }
          FileUtils.mv extracted, @module_dir
        ensure
          build_dir.rmtree
        end
      end

      def delete_existing_installation_or_abort!
        return unless @module_dir.exist?
        FileUtils.rm_rf(@module_dir, :secure => true)
      end
    end
  end
end
