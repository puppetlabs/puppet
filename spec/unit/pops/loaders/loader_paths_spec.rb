require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'loader paths' do
  include PuppetSpec::Files

  let(:static_loader) { Puppet::Pops::Loader::StaticLoader.new() }
  let(:unused_loaders) { nil }

  describe 'the relative_path_for_types method' do
    it 'produces paths to load in precendence order' do
      module_dir = dir_containing('testmodule', {
        'functions' => {},
        'lib' => {
          'puppet' => {
            'functions' => {},
          }}})
      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, unused_loaders, 'testmodule', module_dir, 'test1')

      effective_paths = Puppet::Pops::Loader::LoaderPaths.relative_paths_for_type(:function, module_loader)

      expect(effective_paths.collect(&:generic_path)).to eq([
        File.join(module_dir, 'lib', 'puppet', 'functions')
      ])
    end

    it 'module loader has smart-paths that prunes unavailable paths' do
      module_dir = dir_containing('testmodule', {'lib' => {'puppet' => {'functions' => {'foo.rb' => 'Puppet::Functions.create_function("testmodule::foo") { def foo; end; }' }}}})
      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, unused_loaders, 'testmodule', module_dir, 'test1')

      effective_paths = module_loader.smart_paths.effective_paths(:function)

      expect(effective_paths.size).to be_eql(1)
      expect(effective_paths[0].generic_path).to be_eql(File.join(module_dir, 'lib', 'puppet', 'functions'))
    end

    it 'all function smart-paths produces entries if they exist' do
      module_dir = dir_containing('testmodule', {
        'lib' => {
          'puppet' => {
            'functions' => {'foo4x.rb' => 'ignored in this test'},
          }}})
      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, unused_loaders, 'testmodule', module_dir, 'test1')

      effective_paths = module_loader.smart_paths.effective_paths(:function)

      expect(effective_paths.size).to eq(1)
      expect(module_loader.path_index.size).to eq(1)
      path_index = module_loader.path_index
      expect(path_index).to include(File.join(module_dir, 'lib', 'puppet', 'functions', 'foo4x.rb'))
    end
  end
end
