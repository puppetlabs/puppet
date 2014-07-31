require 'fileutils'
require 'json'
require 'puppet/file_system'

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
        sanity_check
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

      def sanity_check
        symlinks = Dir.glob("#{@path}/**/*", File::FNM_DOTMATCH).map { |f| Pathname.new(f) }.select {|p| Puppet::FileSystem.symlink? p}
        dirpath = Pathname.new @path

        unless symlinks.empty?
          symlinks.each do |s|
            Puppet.warning "Symlinks in modules are unsupported. Please investigate symlink #{s.relative_path_from dirpath}->#{s.realpath.relative_path_from dirpath}."
          end

          raise Puppet::ModuleTool::Errors::ModuleToolError, "Found symlinks. Symlinks in modules are not allowed, please remove them."
        end
      end

      def write_json
        metadata_path = File.join(build_path, 'metadata.json')

        if metadata.to_hash.include? 'checksums'
          Puppet.warning "A 'checksums' field was found in metadata.json. This field will be ignored and can safely be removed."
        end

        # TODO: This may necessarily change the order in which the metadata.json
        # file is packaged from what was written by the user.  This is a
        # regretable, but required for now.
        File.open(metadata_path, 'w') do |f|
          f.write(metadata.to_json)
        end

        File.open(File.join(build_path, 'checksums.json'), 'w') do |f|
          f.write(PSON.pretty_generate(Checksums.new(build_path)))
        end
      end

      def build_path
        @build_path ||= File.join(@pkg_path, metadata.release_name)
      end
    end
  end
end
