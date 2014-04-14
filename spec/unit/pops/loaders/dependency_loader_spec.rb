require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'dependency loader' do
  include PuppetSpec::Files

  let(:static_loader) { Puppet::Pops::Loader::StaticLoader.new() }

  describe 'FileBased module loader' do
    it 'load something in global name space raises an error' do
      module_dir = dir_containing('testmodule', {
      'functions' => {
        'foo.pp' => 'function foo() { yay }'}})

      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, 'testmodule', module_dir, 'test1')
      dep_loader = Puppet::Pops::Loader::DependencyLoader.new(static_loader, 'test-dep', [module_loader])
      expect do
        dep_loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      end.to raise_error(Puppet::ParseError, /A Puppet Function must be defined within a module name-space. The name 'foo' is unacceptable/)
    end

    it 'can load something in a qualified name space' do
      module_dir = dir_containing('testmodule', {
      'functions' => {
          'foo.pp' => 'function testmodule::foo() { yay }'}})

      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, 'testmodule', module_dir, 'test1')
      dep_loader = Puppet::Pops::Loader::DependencyLoader.new(static_loader, 'test-dep', [module_loader])
      function = dep_loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end
