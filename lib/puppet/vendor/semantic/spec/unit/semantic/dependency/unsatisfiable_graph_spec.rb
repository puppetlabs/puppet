require 'spec_helper'
require 'semantic/dependency/unsatisfiable_graph'

describe Semantic::Dependency::UnsatisfiableGraph do

  let(:modules) { %w[ foo bar baz ] }
  let(:graph) { double('Graph', :modules => modules) }
  let(:instance) { described_class.new(graph) }

  subject { instance }

  describe '#message' do
    subject { instance.message }

    it { should match /#{instance.send(:sentence_from_list, modules)}/ }
  end

  describe '#sentence_from_list' do

    subject { instance.send(:sentence_from_list, modules) }

    context 'with a list of one item' do
      let(:modules) { %w[ foo ] }
      it { should eql 'foo' }
    end

    context 'with a list of two items' do
      let(:modules) { %w[ foo bar ] }
      it { should eql 'foo and bar' }
    end

    context 'with a list of three items' do
      let(:modules) { %w[ foo bar baz ] }
      it { should eql 'foo, bar, and baz' }
    end

    context 'with a list of more than three items' do
      let(:modules) { %w[ foo bar baz quux ] }
      it { should eql 'foo, bar, baz, and quux' }
    end

  end

end
