require 'fileutils'
require 'json'

module Puppet::ModuleTool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = Pathname.new(File.expand_path(path))
        @pkg_path = File.join(@path, 'pkg')
        @exclude = options[:exclude]
        @exclude = Regexp.new(@exclude.split(',').join("|")) unless @exclude.nil?
        super(options)
      end

      def run
        load_modulefile!
        create_directory
        copy_contents
        add_metadata
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
        @path.find do |descendant|
          next if @path == descendant
          relative_path = descendant.relative_path_from(@path)
          if Puppet::ModuleTool.artifact?(descendant) or (@exclude and @exclude.match(relative_path.to_s))
            Find.prune
          else
            path = File.join(build_path, relative_path)
            File.file?(descendant) ? FileUtils.copy(descendant, path, :preserve => true) : FileUtils.mkdir(path)
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
