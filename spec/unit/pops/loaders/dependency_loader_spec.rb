require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'dependency loader' do
  include PuppetSpec::Files

  let(:static_loader) { Puppet::Pops::Loader::StaticLoader.new() }
  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }

  describe 'FileBased module loader' do
    it 'load something in global name space raises an error' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      expect do
        loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      end.to raise_error(ArgumentError, /produced mis-matched name, expected 'testmodule::foo', got foo/)
    end

    it 'can load something in a qualified name space' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("testmodule::foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value

      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end

    it 'can load something in a qualified name space more than once' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("testmodule::foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end
  end

  def loader_for(name, dir)
      module_loader = Puppet::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, loaders, name, dir)
      Puppet::Pops::Loader::DependencyLoader.new(static_loader, 'test-dep', [module_loader])
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end
