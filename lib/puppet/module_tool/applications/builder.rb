require 'fileutils'
require 'find'
require 'json'
require 'pathname'

module Puppet::ModuleTool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = Pathname.new(File.expand_path(path))
        @pkg_path = File.join(@path, 'pkg')
        @ignore_path = File.join(@path, '.pmtignore')
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
        ignore_globs = []

        if File.file? @ignore_path
          File.open(@ignore_path).each do |f|
            f.strip!

            if f.empty? || f =~ /^#/
              next
            end

            ignore_globs << f
          end
        end

        @path.find do |descendant|
          next if @path == descendant
          rel = descendant.relative_path_from(@path)
          if Puppet::ModuleTool.artifact?(descendant) || ignore_globs.collect { |glob| File.fnmatch?(glob, rel) }.any?
            Find.prune
          else
            dest = File.join(build_path, rel)
            if File.file?(descendant)
              FileUtils.copy(descendant, dest, :preserve => true)
            else
              FileUtils.mkdir(dest, :mode => File.stat(descendant).mode)
            end
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
