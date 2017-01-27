require 'semantic_puppet'

module SemanticPuppet
  module Dependency
    extend self

    autoload :Graph,         'semantic_puppet/dependency/graph'
    autoload :GraphNode,     'semantic_puppet/dependency/graph_node'
    autoload :ModuleRelease, 'semantic_puppet/dependency/module_release'
    autoload :Source,        'semantic_puppet/dependency/source'

    autoload :UnsatisfiableGraph, 'semantic_puppet/dependency/unsatisfiable_graph'

    # @!group Sources

    # @return [Array<Source>] a frozen copy of the {Source} list
    def sources
      (@sources ||= []).dup.freeze
    end

    # Appends a new {Source} to the current list.
    # @param source [Source] the {Source} to add
    # @return [void]
    def add_source(source)
      sources
      @sources << source
      nil
    end

    # Clears the current list of {Source}s.
    # @return [void]
    def clear_sources
      sources
      @sources.clear
      nil
    end

    # @!endgroup

    # Fetches a graph of modules and their dependencies from the currently
    # configured list of {Source}s.
    #
    # @todo Return a specialized "Graph" object.
    # @todo Allow for external constraints to be added to the graph.
    # @see #sources
    # @see #add_source
    # @see #clear_sources
    #
    # @param modules [{ String => String }]
    # @return [Graph] the root of a dependency graph
    def query(modules)
      constraints = Hash[modules.map { |k, v| [ k, VersionRange.parse(v) ] }]

      graph = Graph.new(constraints)
      fetch_dependencies(graph)
      return graph
    end

    # Given a graph result from {#query}, this method will resolve the graph of
    # dependencies, if possible, into a flat list of the best suited modules. If
    # the dependency graph does not have a suitable resolution, this method will
    # raise an exception to that effect.
    #
    # @param graph [Graph] the root of a dependency graph
    # @return [Array<ModuleRelease>] the list of releases to act on
    def resolve(graph)
      catch :next do
        return walk(graph, graph.dependencies.dup)
      end
      raise UnsatisfiableGraph.new(graph)
    end

    # Fetches all available releases for the given module name.
    #
    # @param name [String] the module name to find releases for
    # @return [Array<ModuleRelease>] the available releases
    def fetch_releases(name)
      releases = {}

      sources.each do |source|
        source.fetch(name).each do |dependency|
          releases[dependency.version] ||= dependency
        end
      end

      return releases.values
    end

    private

    # Iterates over a changing set of dependencies in search of the best
    # solution available. Fitness is specified as meeting all the constraints
    # placed on it, being {ModuleRelease#satisfied? satisfied}, and having the
    # greatest version number (with stability being preferred over prereleases).
    #
    # @todo Traversal order is not presently guaranteed.
    #
    # @param graph [Graph] the root of a dependency graph
    # @param dependencies [{ String => Array<ModuleRelease> }] the dependencies
    # @param considering [Array<GraphNode>] the set of releases being tested
    # @return [Array<GraphNode>] the list of releases to use, if successful
    def walk(graph, dependencies, *considering)
      return considering if dependencies.empty?

      # Selecting a dependency from the collection...
      name = dependencies.keys.sort.first
      deps = dependencies.delete(name)

      # ... (and stepping over it if we've seen it before) ...
      unless (deps & considering).empty?
        return walk(graph, dependencies, *considering)
      end

      # ... we'll iterate through the list of possible versions in order.
      preferred_releases(deps).reverse_each do |dep|

        # We should skip any releases that violate any module's constraints.
        unless [graph, *considering].all? { |x| x.satisfies_constraints?(dep) }
          next
        end

        # We should skip over any releases that violate graph-level constraints.
        potential_solution = considering.dup << dep
        unless graph.satisfies_graph? potential_solution
          next
        end

        catch :next do
          # After adding any new dependencies and imposing our own constraints
          # on existing dependencies, we'll mark ourselves as "under
          # consideration" and recurse.
          merged = dependencies.merge(dep.dependencies) { |_,a,b| a & b }

          # If all subsequent dependencies resolved well, the recursive call
          # will return a completed dependency list. If there were problems
          # resolving our dependencies, we'll catch `:next`, which will cause
          # us to move to the next possibility.
          return walk(graph, merged, *potential_solution)
        end
      end

      # Once we've exhausted all of our possible versions, we know that our
      # last choice was unusable, so we'll unwind the stack and make a new
      # choice.
      throw :next
    end

    # Given a {ModuleRelease}, this method will iterate through the current
    # list of {Source}s to find the complete list of versions available for its
    # dependencies.
    #
    # @param node [GraphNode] the node to fetch details for
    # @return [void]
    def fetch_dependencies(node, cache = {})
      node.dependency_names.each do |name|
        unless cache.key?(name)
          cache[name] = fetch_releases(name)
          cache[name].each { |dep| fetch_dependencies(dep, cache) }
        end

        node << cache[name]
      end
    end

    # Given a list of potential releases, this method returns the most suitable
    # releases for exploration. Only {ModuleRelease#satisfied? satisfied}
    # releases are considered, and releases with stable versions are preferred.
    #
    # @param releases [Array<ModuleRelease>] a list of potential releases
    # @return [Array<ModuleRelease>] releases open for consideration
    def preferred_releases(releases)
      satisfied = releases.select { |x| x.satisfied? }

      if satisfied.any? { |x| x.version.stable? }
        return satisfied.select { |x| x.version.stable? }
      else
        return satisfied
      end
    end
  end
end
