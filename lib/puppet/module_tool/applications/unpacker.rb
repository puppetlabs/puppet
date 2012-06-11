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
          if Facter.value('operatingsystem') == "Solaris"
            # Solaris tar is not safe and works differently, so we use gnutar
            # instead. Since gtar isn't ordinarily in the path, we're providing
            # an absolute path.
            unless File.exists?("/usr/sfw/bin/gtar")
              raise RuntimeError, "Missing executable /usr/sfw/bin/gtar (provided by package SUNWgtar). Unable to extract file."
            end
            untar_cmd = "/usr/sfw/bin/gtar xzf #{@filename} -C #{build_dir}"
          else
            untar_cmd = "tar xzf #{@filename} -C #{build_dir}"
          end

          unless system untar_cmd
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
