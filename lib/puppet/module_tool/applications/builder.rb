require 'zlib'
require 'puppet/util/archive/tar/minitar'
require 'pathname'

module Puppet::ModuleTool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = Pathname.new(File.expand_path(path))
        super(options)
      end

      def run
        load_modulefile!
        Puppet.notice "Building #{@path} for release"
        module_tar_gz = @path.join('pkg', metadata.release_name + '.tar.gz')
        create_module_tar_gz module_tar_gz

        # Return the Pathname object representing the path to the release
        # archive just created. This return value is used by the module_tool
        # face build action, and displayed to on the console using the to_s
        # method.
        #
        # Example return value:
        #
        #   <Pathname:puppetlabs-apache/pkg/puppetlabs-apache-0.0.1.tar.gz>
        #
        module_tar_gz.relative_path_from(Pathname.new(File.expand_path(Dir.pwd)))
      end

      private

      def self.default_user_and_group(opts = {})
        opts = Hash[opts]
        opts[:uname] ||= 'puppet'
        opts[:uid]   ||= 5000
        opts[:gname] ||= 'puppet'
        opts[:gid]   ||= 5000
        opts
      end

      def create_module_tar_gz(module_tar_gz)
        module_tar_gz.dirname.mkdir rescue nil
        Zlib::GzipWriter.open(module_tar_gz) do |gzip|
          Puppet::Util::Archive::Tar::Minitar::Writer.open(gzip) do |tar|
            add_metadata(tar)
            Dir.foreach(@path) do |file|
              case File.basename(file)
                when *Puppet::ModuleTool::ARTIFACTS
                  next
                else
                  add_artifact(tar, @path + file)
              end
            end
          end
        end
      end

      def add_artifact(tar, artifact)
        relative_path = metadata.release_name + '/' + artifact.relative_path_from(@path).to_s
        stat = artifact.lstat
        case
          when stat.directory?
            tar.mkdir(relative_path,
              self.class.default_user_and_group(:mode => stat.mode, :mtime => stat.mtime)
            )
            Dir.foreach(artifact) do |file|
              next if (file == '.' || file == '..')
              add_artifact(tar, artifact + file)
            end
          when stat.file?
            tar.add_file_simple(relative_path,
              self.class.default_user_and_group(:mode => stat.mode, :size => stat.size, :mtime => stat.mtime)
            ) do |entry|
              File.open(artifact, 'rb') do |f|
                while data = f.read(8192)
                  entry.write(data)
                end
              end
            end
          when stat.symlink?
            tar.add_symlink(relative_path, File.readlink(artifact),
              self.class.default_user_and_group(:mode => stat.mode, :mtime => stat.mtime)
            )
          else
            raise ArgumentError, "unsupported file type: #{stat.ftype}"
        end
      end

      def add_metadata(tar)
        serialized_metadata = PSON.pretty_generate(metadata)
        tar.add_file_simple(metadata.release_name + '/' + 'metadata.json',
          self.class.default_user_and_group(:mode => 0644, :size => serialized_metadata.bytesize, :mtime => Time.now.to_i)
        ) do |entry|
          entry.write(serialized_metadata)
        end
      end
    end
  end
end
