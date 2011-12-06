require 'fileutils'

module Puppet::Module::Tool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = File.expand_path(Puppet::Module::Tool.find_module_root(path))
        @pkg_path = File.join(@path, 'pkg')
        super(options)
      end

      def run
        load_modulefile!
        create_directory
        copy_contents
        add_metadata
        Puppet.notice "Building #{@path} for release"
        tar
        gzip
        relative = Pathname.new(File.join(@pkg_path, filename('tar.gz'))).relative_path_from(Pathname.new(Dir.pwd))

        # Return the Pathname object representing the path to the release
        # archive just created. This return value is used by the module_tool
        # face build action, and displayed to on the console using the to_s
        # method.
        #
        # Example return value:
        #
        #   <Pathname:puppetlabs-apache/pkg/puppetlabs-apache-0.0.1.tar.gz>
        #
        relative
      end

      private

      def filename(ext)
        ext.sub!(/^\./, '')
        "#{metadata.release_name}.#{ext}"
      end

      def tar
        tar_name = filename('tar')
        Dir.chdir(@pkg_path) do
          FileUtils.rm tar_name rescue nil
          unless system "tar -cf #{tar_name} #{metadata.release_name}"
            raise RuntimeError, "Could not create #{tar_name}"
          end
        end
      end

      def gzip
        Dir.chdir(@pkg_path) do
          FileUtils.rm filename('tar.gz') rescue nil
          unless system "gzip #{filename('tar')}"
            raise RuntimeError, "Could not compress #{filename('tar')}"
          end
        end
      end

      def create_directory
        FileUtils.mkdir(@pkg_path) rescue nil
        if File.directory?(build_path)
          FileUtils.rm_rf(build_path)
        end
        FileUtils.mkdir(build_path)
      end

      def copy_contents
        Dir[File.join(@path, '*')].each do |path|
          case File.basename(path)
          when *Puppet::Module::Tool::ARTIFACTS
            next
          else
            FileUtils.cp_r path, build_path
          end
        end
      end

      def add_metadata
        File.open(File.join(build_path, 'metadata.json'), 'w') do |f|
          f.write(PSON.pretty_generate(metadata))
        end
      end

      def build_path
        @build_path ||= File.join(@pkg_path, metadata.release_name)
      end
    end
  end
end
