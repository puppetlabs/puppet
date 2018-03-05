require 'pathname'
require 'tmpdir'
require 'puppet/util/json'
require 'puppet/file_system'

module Puppet::ModuleTool
  module Applications
    class Unpacker < Application
      def self.unpack(filename, target)
        app = self.new(filename, :target_dir => target)
        app.unpack
        app.sanity_check
        app.move_into(target)
      end

      def self.harmonize_ownership(source, target)
        unless Puppet.features.microsoft_windows?
          source = Pathname.new(source) unless source.respond_to?(:stat)
          target = Pathname.new(target) unless target.respond_to?(:stat)

          FileUtils.chown_R(source.stat.uid, source.stat.gid, target)
        end
      end

      def initialize(filename, options = {})
        @filename = Pathname.new(filename)
        super(options)
        @module_path = Pathname(options[:target_dir])
      end

      def run
        unpack
        sanity_check
        module_dir = @module_path + module_name
        move_into(module_dir)

        # Return the Pathname object representing the directory where the
        # module release archive was unpacked the to.
        return module_dir
      end

      # @api private
      # Error on symlinks and other junk
      def sanity_check
        symlinks = Dir.glob("#{tmpdir}/**/*", File::FNM_DOTMATCH).map { |f| Pathname.new(f) }.select {|p| Puppet::FileSystem.symlink? p}
        tmpdirpath = Pathname.new tmpdir

        symlinks.each do |s|
          Puppet.warning _("Symlinks in modules are unsupported. Please investigate symlink %{from}->%{to}.") % { from: s.relative_path_from(tmpdirpath), to: Puppet::FileSystem.readlink(s) }
        end
      end

      # @api private
      def unpack
        begin
          Puppet::ModuleTool::Tar.instance.unpack(@filename.to_s, tmpdir, [@module_path.stat.uid, @module_path.stat.gid].join(':'))
        rescue Puppet::ExecutionFailure => e
          raise RuntimeError, _("Could not extract contents of module archive: %{message}") % { message: e.message }
        end
      end

      # @api private
      def root_dir
        return @root_dir if @root_dir

        # Grab the first directory containing a metadata.json file
        metadata_file = Dir["#{tmpdir}/**/metadata.json"].sort_by(&:length)[0]

        if metadata_file
          @root_dir = Pathname.new(metadata_file).dirname
        else
          raise _("No valid metadata.json found!")
        end
      end

      # @api private
      def module_name
        metadata = Puppet::Util::Json.load((root_dir + 'metadata.json').read)
        metadata['name'][/-(.*)/, 1]
      end

      # @api private
      def move_into(dir)
        dir = Pathname.new(dir)
        dir.rmtree if dir.exist?
        FileUtils.mv(root_dir, dir)
      ensure
        FileUtils.rmtree(tmpdir)
      end

      # Obtain a suitable temporary path for unpacking tarballs
      #
      # @api private
      # @return [String] path to temporary unpacking location
      def tmpdir
        @dir ||= Dir.mktmpdir('tmp', Puppet::Forge::Cache.base_path)
      end
    end
  end
end
