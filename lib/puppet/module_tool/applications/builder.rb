require 'fileutils'
require 'puppet/util/json'
require 'puppet/file_system'
require 'pathspec'
require 'facter'

module Puppet::ModuleTool
  module Applications
    class Builder < Application

      def initialize(path, options = {})
        @path = File.expand_path(path)
        @pkg_path = File.join(@path, 'pkg')
        super(options)
      end

      def run
        # Disallow anything that invokes md5 to avoid un-friendly termination due to FIPS
        raise _("Module building is prohibited in FIPS mode.") if Facter.value(:fips_enabled)

        load_metadata!
        create_directory
        copy_contents
        write_json
        Puppet.notice _("Building %{path} for release") % { path: @path }
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

      def ignored_files
        if @ignored_files
          return @ignored_files
        else
          pmtignore = File.join(@path, '.pmtignore')
          gitignore = File.join(@path, '.gitignore')

          if File.file? pmtignore
            @ignored_files = PathSpec.new Puppet::FileSystem.read(pmtignore, :encoding => 'utf-8')
          elsif File.file? gitignore
            @ignored_files = PathSpec.new Puppet::FileSystem.read(gitignore, :encoding => 'utf-8')
          else
            @ignored_files = PathSpec.new
          end
        end
      end

      def copy_contents
        symlinks = []
        Find.find(File.join(@path)) do |path|
          # because Find.find finds the path itself
          if path == @path
            next
          end

          # Needed because pathspec looks for a trailing slash in the path to
          # determine if a path is a directory
          path = path.to_s + '/' if File.directory? path

          # if it matches, then prune it with fire
          unless ignored_files.match_paths([path], @path).empty?
            Find.prune
          end

          # don't copy all the Puppet ARTIFACTS
          rel = Pathname.new(path).relative_path_from(Pathname.new(@path))
          case rel.to_s
          when *Puppet::ModuleTool::ARTIFACTS
            Find.prune
          end

          # make dir tree, copy files, and add symlinks to the symlinks list
          dest = "#{build_path}/#{rel.to_s}"
          if File.directory? path
            FileUtils.mkdir dest, :mode => File.stat(path).mode
          elsif Puppet::FileSystem.symlink? path
            symlinks << path
          else
            FileUtils.cp path, dest, :preserve => true
          end
        end

        # send a message about each symlink and raise an error if they exist
        unless symlinks.empty?
          symlinks.each do |s|
            s = Pathname.new s
            mpath = Pathname.new @path
            Puppet.warning _("Symlinks in modules are unsupported. Please investigate symlink %{from} -> %{to}.") % { from: s.relative_path_from(mpath), to: s.realpath.relative_path_from(mpath) }
          end

          raise Puppet::ModuleTool::Errors::ModuleToolError, _("Found symlinks. Symlinks in modules are not allowed, please remove them.")
        end
      end

      def write_json
        metadata_path = File.join(build_path, 'metadata.json')

        if metadata.to_hash.include? 'checksums'
          Puppet.warning _("A 'checksums' field was found in metadata.json. This field will be ignored and can safely be removed.")
        end

        # TODO: This may necessarily change the order in which the metadata.json
        # file is packaged from what was written by the user.  This is a
        # regretable, but required for now.
        Puppet::FileSystem.open(metadata_path, nil, 'w:UTF-8') do |f|
          f.write(metadata.to_json)
        end

        Puppet::FileSystem.open(File.join(build_path, 'checksums.json'), nil, 'wb') do |f|
          f.write(Puppet::Util::Json.dump(Checksums.new(build_path), :pretty => true))
        end
      end

      def build_path
        @build_path ||= File.join(@pkg_path, metadata.release_name)
      end
    end
  end
end
