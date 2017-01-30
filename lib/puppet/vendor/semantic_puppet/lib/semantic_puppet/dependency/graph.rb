require 'semantic_puppet/dependency'

module SemanticPuppet
  module Dependency
    class Graph
      include GraphNode

      attr_reader :modules

      # Create a new instance of a dependency graph.
      #
      # @param modules [{String => VersionRange}] the required module
      #        set and their version constraints
      def initialize(modules = {})
        @modules = modules.keys

        modules.each do |name, range|
          add_constraint('initialize', name, range.to_s) do |node|
            range === node.version
          end

          add_dependency(name)
        end
      end

      # Constrains graph solutions based on the given block.  Graph constraints
      # are used to describe fundamental truths about the tooling or module
      # system (e.g.: module names contain a namespace component which is
      # dropped during install, so module names must be unique excluding the
      # namespace).
      #
      # @example Ensuring a single source for all modules
      #     @graph.add_constraint('installed', mod.name) do |nodes|
      #       nodes.count { |node| node.source } == 1
      #     end
      #
      # @see #considering_solution?
      #
      # @param source [String, Symbol] a name describing the source of the
      #               constraint
      # @yieldparam nodes [Array<GraphNode>] the nodes to test the constraint
      #             against
      # @yieldreturn [Boolean] whether the node passed the constraint
      # @return [void]
      def add_graph_constraint(source, &block)
        constraints[:graph] << [ source, block ]
      end

      # Checks the proposed solution (or partial solution) against the graph's
      # constraints.
      #
      # @see #add_graph_constraint
      #
      # @return [Boolean] true if none of the graph constraints are violated
      def satisfies_graph?(solution)
        constraints[:graph].all? { |_, check| check[solution] }
      end
    end
  end
end
