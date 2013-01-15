require 'zlib'
require 'puppet/util/archive/tar/minitar'
require 'pathname'

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
          begin
            Zlib::GzipReader.open(@filename) do |gzip|
              Puppet::Util::Archive::Tar::Minitar::Reader.open(gzip) do |tar|
                tar.each do |entry|
                  destination_file = Pathname.new(entry.full_name).cleanpath
                  if destination_file.absolute? ||
                    (destination_file_path = destination_file.to_s).start_with?('..') &&
                    (destination_file_path.length == 2 || destination_file_path[2..2] == '/')
                  then
                    raise ArgumentError, "tar entry outside of the module directory: #{entry.full_name}"
                  end
                  destination_file = build_dir + destination_file
                  destination_directory = destination_file.dirname
                  destination_directory.mkpath() unless destination_directory.directory?

                  mode = entry.mode
                  case
                    when entry.directory?
                      destination_file.mkdir(mode) unless destination_file.directory?
                      destination_file.chmod(mode)
                    when entry.file?
                      destination_file.unlink() if (destination_file.exist? || destination_file.symlink?)
                      destination_file.open(File::WRONLY|File::CREAT|File::EXCL, mode) do |f|
                        # fix the mode as it was probably influenced by umask
                        f.chmod(mode)
                        f.binmode()
                        while data = entry.read(8192)
                          f.write(data)
                        end
                      end
                    when entry.symlink?
                      File.symlink(entry.linkname, destination_file)
                    else
                      raise ArgumentError, "unsupported tar entry type: #{entry.typeflag}"
                  end
                end
              end
            end
          rescue => e
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
