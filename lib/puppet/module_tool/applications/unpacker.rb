require 'pathname'
require 'tmpdir'

module Puppet::ModuleTool
  module Applications
    class Unpacker < Application

      def initialize(filename, options = {})
        @filename = Pathname.new(filename)
        parsed = parse_filename(filename)
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

      private
      def extract_module_to_install_dir
        delete_existing_installation_or_abort!

        build_dir = Puppet::Forge::Cache.base_path + "tmp-unpacker-#{Digest::SHA1.hexdigest(@filename.basename.to_s)}"
        build_dir.mkpath
        begin
          unless system "tar xzf #{@filename} -C #{build_dir}"
            raise RuntimeError, "Could not extract contents of module archive."
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
