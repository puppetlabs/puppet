require 'semantic_puppet/dependency'
require 'set'

module SemanticPuppet
  module Dependency
    module GraphNode
      include Comparable

      def name
      end

      # Determines whether the modules dependencies are satisfied by the known
      # releases.
      #
      # @return [Boolean] true if all dependencies are satisfied
      def satisfied?
        dependencies.none? { |_, v| v.empty? }
      end

      def children
        @_children ||= {}
      end

      def populate_children(nodes)
        if children.empty?
          nodes = nodes.select { |node| satisfies_dependency?(node) }
          nodes.each do |node|
            children[node.name] = node
            node.populate_children(nodes)
          end
          self.freeze
        end
      end

      # @api internal
      # @return [{ String => SortedSet<GraphNode> }] the satisfactory
      #         dependency nodes
      def dependencies
        @_dependencies ||= Hash.new { |h, k| h[k] = SortedSet.new }
      end

      # Adds the given dependency name to the list of dependencies.
      #
      # @param name [String] the dependency name
      # @return [void]
      def add_dependency(name)
        dependencies[name]
      end

      # @return [Array<String>] the list of dependency names
      def dependency_names
        dependencies.keys
      end

      def constraints
        @_constraints ||= Hash.new { |h, k| h[k] = [] }
      end

      def constraints_for(name)
        return [] unless constraints.has_key?(name)

        constraints[name].map do |constraint|
          {
            :source      => constraint[0],
            :description => constraint[1],
            :test        => constraint[2],
          }
        end
      end

      # Constrains the named module to suitable releases, as determined by the
      # given block.
      #
      # @example Version-locking currently installed modules
      #     installed_modules.each do |m|
      #       @graph.add_constraint('installed', m.name, m.version) do |node|
      #         m.version == node.version
      #       end
      #     end
      #
      # @param source [String, Symbol] a name describing the source of the
      #               constraint
      # @param mod [String] the name of the module
      # @param desc [String] a description of the enforced constraint
      # @yieldparam node [GraphNode] the node to test the constraint against
      # @yieldreturn [Boolean] whether the node passed the constraint
      # @return [void]
      def add_constraint(source, mod, desc, &block)
        constraints["#{mod}"] << [ source, desc, block ]
      end

      def satisfies_dependency?(node)
        dependencies.key?(node.name) && satisfies_constraints?(node)
      end

      # @param release [ModuleRelease] the release to test
      def satisfies_constraints?(release)
        constraints_for(release.name).all? { |x| x[:test].call(release) }
      end

      def << (nodes)
        Array(nodes).each do |node|
          next unless dependencies.key?(node.name)
          if satisfies_dependency?(node)
            dependencies[node.name] << node
          end
        end

        return self
      end

      def <=>(other)
        name <=> other.name
      end
    end
  end
end
