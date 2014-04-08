require 'semantic/dependency'

module Semantic
  module Dependency
    class ModuleRelease
      include GraphNode

      attr_reader :name, :version

      # Create a new instance of a module release.
      #
      # @param source [Semantic::Dependency::Source]
      # @param name [String]
      # @param version [Semantic::Version]
      # @param dependencies [{String => Semantic::VersionRange}]
      def initialize(source, name, version, dependencies = {})
        @source      = source
        @name        = name.freeze
        @version     = version.freeze

        dependencies.each do |name, range|
          add_constraint('initialize', name, range.to_s) do |node|
            range === node.version
          end

          add_dependency(name)
        end
      end

      def priority
        @source.priority
      end

      def <=>(oth)
        our_key   = [ priority, name, version ]
        their_key = [ oth.priority, oth.name, oth.version ]

        return our_key <=> their_key
      end

      def to_s
        "#<#{self.class} #{name}@#{version}>"
      end
    end
  end
end
