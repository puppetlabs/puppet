require 'fileutils'
require 'json'

module Puppet::ModuleTool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = File.expand_path(path)
        @pkg_path = File.join(@path, 'pkg')
        super(options)
      end

      def run
        load_metadata!
        create_directory
        copy_contents
        write_json
        Puppet.notice "Building #{@path} for release"
        pack
        relative = Pathname.new(archive_file).relative_path_from(Pathname.new(File.expand_path(Dir.pwd)))

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

      def archive_file
        File.join(@pkg_path, "#{metadata.release_name}.tar.gz")
      end

      def pack
        FileUtils.rm archive_file rescue nil

        tar = Puppet::ModuleTool::Tar.instance
        Dir.chdir(@pkg_path) do
          tar.pack(metadata.release_name, archive_file)
        end
      end

      def create_directory
        FileUtils.mkdir(@pkg_path) rescue nil
        if File.directory?(build_path)
          FileUtils.rm_rf(build_path, :secure => true)
        end
        FileUtils.mkdir(build_path)
      end

      def copy_contents
        Dir[File.join(@path, '*')].each do |path|
          case File.basename(path)
          when *Puppet::ModuleTool::ARTIFACTS
            next
          else
            FileUtils.cp_r path, build_path, :preserve => true
          end
        end
      end

      def write_json
        metadata_path = File.join(build_path, 'metadata.json')

        # TODO: This may necessarily change the order in which the metadata.json
        # file is packaged from what was written by the user.  This is a
        # regretable, but required for now.
        File.open(metadata_path, 'w') do |f|
          f.write(metadata.to_json)
        end

        File.open(File.join(build_path, 'checksums.json'), 'w') do |f|
          f.write(PSON.pretty_generate(Checksums.new(@path)))
        end
      end

      def build_path
        @build_path ||= File.join(@pkg_path, metadata.release_name)
      end
    end
  end
end
