require 'spec_helper'
require 'semantic/dependency/graph_node'

describe Semantic::Dependency::GraphNode do
  let(:klass) do
    Class.new do
      include Semantic::Dependency::GraphNode

      attr_accessor :name

      def initialize(name, *satisfying)
        @name = name
        @satisfying = satisfying
        @satisfying.each { |x| add_dependency(x.name) }
      end

      # @override
      def satisfies_dependency?(node)
        @satisfying.include?(node)
      end
    end
  end

  def instance(*args)
    name = args.first.name unless args.empty?
    klass.new(name || 'unnamed', *args)
  end

  context 'dependencies' do
    subject { instance() }

    example 'are added by #add_dependency' do
      subject.add_dependency('foo')
      subject.add_dependency('bar')
      subject.add_dependency('baz')
      expect(subject.dependency_names).to match_array %w[ foo bar baz ]
    end

    example 'are maintained in the #dependencies Hash' do
      expect(subject.dependencies).to be_empty
      subject.add_dependency('foo')
      expect(subject.dependencies).to have_key 'foo'
      expect(subject.dependencies).to respond_to :to_a
    end
  end

  describe '#<<' do
    let(:foo) { double('Node', :name => 'foo') }
    let(:bar1) { double('Node', :name => 'bar', :'<=>' => 0) }
    let(:bar2) { double('Node', :name => 'bar', :'<=>' => 0) }
    let(:bar3) { double('Node', :name => 'bar') }
    let(:baz) { double('Node', :name => 'baz') }

    subject { instance(foo, bar1, bar2) }

    it 'appends satisfying nodes to the dependencies' do
      subject << foo << bar1 << bar2
      expect(Array(subject.dependencies['foo'])).to match_array [ foo ]
      expect(Array(subject.dependencies['bar'])).to match_array [ bar1, bar2 ]
    end

    it 'does not append nodes with unknown names' do
      subject << baz
      expect(Array(subject.dependencies['baz'])).to be_empty
    end

    it 'does not append unsatisfying nodes' do
      subject << bar3
      expect(Array(subject.dependencies['bar'])).to be_empty
    end
  end

  describe '#satisfied' do
    let(:foo) { double('Node', :name => 'foo') }
    let(:bar) { double('Node', :name => 'bar') }

    subject { instance(foo, bar) }

    it 'is unsatisfied when no nodes have been appended' do
      expect(subject).to_not be_satisfied
    end

    it 'is unsatisfied when any dependencies are missing' do
      subject << foo
      expect(subject).to_not be_satisfied
    end

    it 'is satisfied when all dependencies are fulfilled' do
      subject << foo << bar
      expect(subject).to be_satisfied
    end
  end

  describe '#populate_children' do
    let(:foo) { double('Node', :name => 'foo') }
    let(:bar1) { double('Node', :name => 'bar', :'<=>' => 0) }
    let(:bar2) { double('Node', :name => 'bar', :'<=>' => 0) }
    let(:baz1) { double('Node', :name => 'baz', :'<=>' => 0) }
    let(:baz2) { double('Node', :name => 'baz', :'<=>' => 0) }
    let(:quxx) { double('Node', :name => 'quxx') }

    subject do
      graph = instance(foo, bar1, bar2, baz1, baz2)
      graph << foo << bar1 << bar2 << baz1 << baz2
    end

    it 'saves all relevant nodes as its children' do
      nodes = [ foo, bar2, baz1, quxx ]
      nodes.each do |node|
        allow(node).to receive(:populate_children)
      end

      subject.populate_children(nodes)

      expected = { 'foo' => foo, 'bar' => bar2, 'baz' => baz1 }
      expect(subject.children).to eql expected
    end

    it 'accepts a graph solution and populates it across all nodes' do
      nodes = [ foo, bar2, baz1 ]
      nodes.each do |node|
        expect(node).to receive(:populate_children).with(nodes)
      end

      subject.populate_children(nodes)
    end
  end

  describe '#<=>' do
    it 'can be compared' do
      a = instance(double('Node', :name => 'a'))
      b = instance(double('Node', :name => 'b'))

      expect(a).to be < b
      expect(b).to be > a
      expect([b, a].sort).to eql [a, b]
      expect([a, b].sort).to eql [a, b]
    end
  end

end
