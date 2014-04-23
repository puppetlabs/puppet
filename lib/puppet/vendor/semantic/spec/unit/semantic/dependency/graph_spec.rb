require 'spec_helper'
require 'semantic/dependency/graph'

describe Semantic::Dependency::Graph do
  Graph         = Semantic::Dependency::Graph
  GraphNode     = Semantic::Dependency::GraphNode
  ModuleRelease = Semantic::Dependency::ModuleRelease
  Version       = Semantic::Version
  VersionRange  = Semantic::VersionRange

  describe '#initialize' do
    it 'can be called without arguments' do
      expect { Graph.new }.to_not raise_error
    end

    it 'implements the GraphNode protocol' do
      expect(Graph.new).to be_a GraphNode
    end

    it 'adds constraints for every key in the passed hash' do
      graph = Graph.new('foo' => 1, 'bar' => 2, 'baz' => 3)
      expect(graph.constraints.keys).to match_array %w[ foo bar baz ]
    end

    it 'adds the named dependencies for every key in the passed hash' do
      graph = Graph.new('foo' => 1, 'bar' => 2, 'baz' => 3)
      expect(graph.dependency_names).to match_array %w[ foo bar baz ]
    end
  end

  describe '#add_constraint' do
    let(:graph) { Graph.new }

    it 'can create a new constraint on a module' do
      expect(graph.constraints.keys).to be_empty

      graph.add_constraint('test', 'module-name', 'nil') { }
      expect(graph.constraints.keys).to match_array %w[ module-name ]
    end

    it 'permits multiple constraints against the same module name' do
      expect(graph.constraints.keys).to be_empty

      graph.add_constraint('test', 'module-name', 'nil') { }
      graph.add_constraint('test', 'module-name', 'nil') { }

      expect(graph.constraints.keys).to match_array %w[ module-name ]
    end
  end

  describe '#satisfies_dependency?' do
    it 'is not satisfied by modules it does not depend on' do
      graph = Graph.new('foo' => VersionRange.parse('1.x'))
      release = ModuleRelease.new(nil, 'bar', Version.parse('1.0.0'))

      expect(graph.satisfies_dependency?(release)).to_not be true
    end

    it 'is not satisfied by modules that do not fulfill the constraint' do
      graph = Graph.new('foo' => VersionRange.parse('1.x'))
      release = ModuleRelease.new(nil, 'foo', Version.parse('2.3.1'))

      expect(graph.satisfies_dependency?(release)).to_not be true
    end

    it 'is not satisfied by modules that do not fulfill all the constraints' do
      graph = Graph.new('foo' => VersionRange.parse('1.x'))
      graph.add_constraint('me', 'foo', '1.2.3') do |node|
        node.version.to_s == '1.2.3'
      end

      release = ModuleRelease.new(nil, 'foo', Version.parse('1.2.1'))

      expect(graph.satisfies_dependency?(release)).to_not be true
    end

    it 'is satisfied by modules that do fulfill all the constraints' do
      graph = Graph.new('foo' => VersionRange.parse('1.x'))
      graph.add_constraint('me', 'foo', '1.2.3') do |node|
        node.version.to_s == '1.2.3'
      end

      release = ModuleRelease.new(nil, 'foo', Version.parse('1.2.3'))

      expect(graph.satisfies_dependency?(release)).to be true
    end
  end

  describe '#add_graph_constraint' do
    let(:graph) { Graph.new }

    it 'can create a new constraint on a graph' do
      expect(graph.constraints.keys).to be_empty

      graph.add_graph_constraint('test') { }
      expect(graph.constraints.keys).to match_array [ :graph ]
    end

    it 'permits multiple graph constraints' do
      expect(graph.constraints.keys).to be_empty

      graph.add_graph_constraint('test') { }
      graph.add_graph_constraint('test') { }

      expect(graph.constraints.keys).to match_array [ :graph ]
    end
  end

  describe '#satisfies_graph?' do
    it 'returns false if the solution violates a graph constraint' do
      graph = Graph.new
      graph.add_graph_constraint('me') do |nodes|
        nodes.none? { |node| node.name =~ /z/ }
      end

      releases = [
        double('Node', :name => 'foo'),
        double('Node', :name => 'bar'),
        double('Node', :name => 'baz'),
      ]

      expect(graph.satisfies_graph?(releases)).to_not be true
    end

    it 'returns false if the solution violates any graph constraint' do
      graph = Graph.new
      graph.add_graph_constraint('me') do |nodes|
        nodes.all? { |node| node.name.length < 5 }
      end
      graph.add_graph_constraint('me') do |nodes|
        nodes.none? { |node| node.name =~ /z/ }
      end

      releases = [
        double('Node', :name => 'foo'),
        double('Node', :name => 'bar'),
        double('Node', :name => 'bangerang'),
      ]

      expect(graph.satisfies_graph?(releases)).to_not be true
    end

    it 'returns true if the solution violates no graph constraints' do
      graph = Graph.new
      graph.add_graph_constraint('me') do |nodes|
        nodes.all? { |node| node.name.length < 5 }
      end
      graph.add_graph_constraint('me') do |nodes|
        nodes.none? { |node| node.name =~ /z/ }
      end

      releases = [
        double('Node', :name => 'foo'),
        double('Node', :name => 'bar'),
        double('Node', :name => 'boom'),
      ]

      expect(graph.satisfies_graph?(releases)).to be true
    end
  end

end
