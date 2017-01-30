require 'semantic_puppet/dependency'

module SemanticPuppet
  module Dependency
    class ModuleRelease
      include GraphNode

      attr_reader :name, :version

      # Create a new instance of a module release.
      #
      # @param source [SemanticPuppet::Dependency::Source]
      # @param name [String]
      # @param version [SemanticPuppet::Version]
      # @param dependencies [{String => SemanticPuppet::VersionRange}]
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

      def eql?(other)
        other.is_a?(ModuleRelease) &&
          @name.eql?(other.name) &&
          @version.eql?(other.version) &&
          dependencies.eql?(other.dependencies)
      end
      alias == eql?

      def hash
        @name.hash ^ @version.hash
      end

      def to_s
        "#<#{self.class} #{name}@#{version}>"
      end
    end
  end
end
