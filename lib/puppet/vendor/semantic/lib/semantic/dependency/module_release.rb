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
        # Note that prior to ruby 2.3.0, if a <=> method threw an exception, ruby
        # would silently rescue the exception and return nil from <=> (which causes
        # the derived == comparison to return false). Starting in ruby 2.3.0, this
        # behavior changed and the exception is actually thrown. Some comments at:
        # https://bugs.ruby-lang.org/issues/7688
        #
        # So simply return nil here if any of the needed fields are not available,
        # since attempting to access a missing field is one way to force an exception.
        # This doesn't help if the  <=> use below throws an exception, but it
        # handles the most typical cause.
        return nil if !oth.respond_to?(:priority) ||
                      !oth.respond_to?(:name)     ||
                      !oth.respond_to?(:version)

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
