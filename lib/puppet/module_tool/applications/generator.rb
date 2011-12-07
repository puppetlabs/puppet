require 'pathname'
require 'fileutils'
require 'erb'

module Puppet::Module::Tool
  module Applications
    class Generator < Application

      def initialize(full_module_name, options = {})
        begin
          @metadata = Metadata.new(:full_module_name => full_module_name)
        rescue ArgumentError
          raise "Could not generate directory #{full_module_name.inspect}, you must specify a dash-separated username and module name."
        end
        super(options)
      end

      def skeleton
        @skeleton ||= Skeleton.new
      end

      def get_binding
        binding
      end

      def run
        if destination.directory?
          raise ArgumentError, "#{destination} already exists."
        end
        Puppet.notice "Generating module at #{Dir.pwd}/#{@metadata.dashed_name}"
        files_created = []
        skeleton.path.find do |path|
          if path == skeleton
            destination.mkpath
          else
            node = Node.on(path, self)
            if node
              node.install!
              files_created << node.target
            else
              Puppet.notice "Could not generate from #{path}"
            end
          end
        end

        # Return an array of Pathname objects representing file paths of files
        # and directories just generated. This return value is used by the
        # module_tool face generate action, and displayed on the console.
        #
        # Example return value:
        #
        #   [
        #     #<Pathname:puppetlabs-apache>,
        #     #<Pathname:puppetlabs-apache/tests>,
        #     #<Pathname:puppetlabs-apache/tests/init.pp>,
        #     #<Pathname:puppetlabs-apache/spec>,
        #     #<Pathname:puppetlabs-apache/spec/spec_helper.rb>,
        #     #<Pathname:puppetlabs-apache/spec/spec.opts>,
        #     #<Pathname:puppetlabs-apache/README>,
        #     #<Pathname:puppetlabs-apache/Modulefile>,
        #     #<Pathname:puppetlabs-apache/metadata.json>,
        #     #<Pathname:puppetlabs-apache/manifests>,
        #     #<Pathname:puppetlabs-apache/manifests/init.pp"
        #   ]
        #
        files_created
      end

      def destination
        @destination ||= Pathname.new(@metadata.dashed_name)
      end

      class Node
        def self.types
          @types ||= []
        end
        def self.inherited(klass)
          types << klass
        end
        def self.on(path, generator)
          klass = types.detect { |t| t.matches?(path) }
          if klass
            klass.new(path, generator)
          end
        end
        def initialize(source, generator)
          @generator = generator
          @source = source
        end
        def read
          @source.read
        end
        def target
          target = @generator.destination + @source.relative_path_from(@generator.skeleton.path)
          components = target.to_s.split(File::SEPARATOR).map do |part|
            part == 'NAME' ? @generator.metadata.name : part
          end
          Pathname.new(components.join(File::SEPARATOR))
        end
        def install!
          raise NotImplementedError, "Abstract"
        end
      end

      class DirectoryNode < Node
        def self.matches?(path)
          path.directory?
        end
        def install!
          target.mkpath
        end
      end

      class ParsedFileNode < Node
        def self.matches?(path)
          path.file? && path.extname == '.erb'
        end
        def target
          path = super
          path.parent + path.basename('.erb')
        end
        def contents
          template = ERB.new(read)
          template.result(@generator.send(:get_binding))
        end
        def install!
          target.open('w') { |f| f.write contents }
        end
      end

      class FileNode < Node
        def self.matches?(path)
          path.file?
        end
        def install!
          FileUtils.cp(@source, target)
        end
      end
    end
  end
end
