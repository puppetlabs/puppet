require 'spec_helper'
require 'semantic/dependency/module_release'

describe Semantic::Dependency::ModuleRelease do
  def source
    @source ||= Semantic::Dependency::Source.new
  end

  def make_release(name, version, deps = {})
    source.create_release(name, version, deps)
  end

  let(:no_dependencies) do
    make_release('module', '1.2.3')
  end

  let(:one_dependency) do
    make_release('module', '1.2.3', 'foo' => '1.0.0')
  end

  let(:three_dependencies) do
    dependencies = { 'foo' => '1.0.0', 'bar' => '2.0.0', 'baz' => '3.0.0' }
    make_release('module', '1.2.3', dependencies)
  end

  describe '#dependency_names' do

    it "lists the names of all the release's dependencies" do
      expect(no_dependencies.dependency_names).to    match_array %w[]
      expect(one_dependency.dependency_names).to     match_array %w[foo]
      expect(three_dependencies.dependency_names).to match_array %w[foo bar baz]
    end

  end

  describe '#to_s' do

    let(:name) { 'foobarbaz' }
    let(:version) { '1.2.3' }

    subject { make_release(name, version).to_s }

    it { should =~ /#{name}/ }
    it { should =~ /#{version}/ }

  end

  describe '#<<' do

    it 'marks matching dependencies as satisfied' do
      one_dependency << make_release('foo', '1.0.0')
      expect(one_dependency).to be_satisfied
    end

    it 'does not mark mis-matching dependency names as satisfied' do
      one_dependency << make_release('WAT', '1.0.0')
      expect(one_dependency).to_not be_satisfied
    end

    it 'does not mark mis-matching dependency versions as satisfied' do
      one_dependency << make_release('foo', '0.0.1')
      expect(one_dependency).to_not be_satisfied
    end

  end

  describe '#<=>' do

    it 'considers releases with greater version numbers greater' do
      expect(make_release('foo', '1.0.0')).to be > make_release('foo', '0.1.0')
    end

    it 'considers releases with lesser version numbers lesser' do
      expect(make_release('foo', '0.1.0')).to be < make_release('foo', '1.0.0')
    end

    it 'orders releases with different names lexographically' do
      expect(make_release('bar', '1.0.0')).to be < make_release('foo', '1.0.0')
    end

    it 'orders releases by name first' do
      expect(make_release('bar', '2.0.0')).to be < make_release('foo', '1.0.0')
    end

  end

  describe '#satisfied?' do

    it 'returns true when there are no dependencies to satisfy' do
      expect(no_dependencies).to be_satisfied
    end

    it 'returns false when no dependencies have been satisified' do
      expect(one_dependency).to_not be_satisfied
    end

    it 'returns false when not all dependencies have been satisified' do
      releases = %w[ 0.9.0 1.0.0 1.0.1 ].map { |ver| make_release('foo', ver) }
      three_dependencies << releases

      expect(three_dependencies).to_not be_satisfied
    end

    it 'returns false when not all dependency versions have been satisified' do
      releases = %w[ 0.9.0 1.0.1 ].map { |ver| make_release('foo', ver) }
      one_dependency << releases

      expect(one_dependency).to_not be_satisfied
    end

    it 'returns true when all dependencies have been satisified' do
      releases = %w[ 0.9.0 1.0.0 1.0.1 ].map { |ver| make_release('foo', ver) }
      one_dependency << releases

      expect(one_dependency).to be_satisfied
    end

  end

  describe '#satisfies_dependency?' do

    it 'returns false when there are no dependencies to satisfy' do
      release = make_release('foo', '1.0.0')
      expect(no_dependencies.satisfies_dependency?(release)).to_not be true
    end

    it 'returns false when the release does not match the dependency name' do
      release = make_release('bar', '1.0.0')
      expect(one_dependency.satisfies_dependency?(release)).to_not be true
    end

    it 'returns false when the release does not match the dependency version' do
      release = make_release('foo', '4.0.0')
      expect(one_dependency.satisfies_dependency?(release)).to_not be true
    end

    it 'returns true when the release matches the dependency' do
      release = make_release('foo', '1.0.0')
      expect(one_dependency.satisfies_dependency?(release)).to be true
    end

  end
end
