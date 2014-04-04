require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'loader paths' do
  include PuppetSpec::Files
  before(:each) { Puppet[:biff] = true }

  let(:static_loader) { Puppet::Pops::Loader::StaticLoader.new() }

  it 'expects dir_containing to create a temp directory structure from a hash' do
    module_dir = dir_containing('testmodule', { 'test.txt' => 'Hello world', 'sub' => { 'foo.txt' => 'foo'}})
    expect(File.read(File.join(module_dir, 'test.txt'))).to be_eql('Hello world')
    expect(File.read(File.join(module_dir, 'sub', 'foo.txt'))).to be_eql('foo')
  end

  describe 'the relative_path_for_types method' do
    it 'produces paths to load in precendence order' do
      module_dir = dir_containing('testmodule', {
        'functions' => {},
        'lib' => {
          'puppet' => {
            'functions' => {},
            'parser' => {
              'functions' => {},
            }
          }}})
       # Must have a File/Path based loader to talk to
       module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, 'testmodule', module_dir, 'test1')
       effective_paths = Puppet::Pops::Loader::LoaderPaths.relative_paths_for_type(:function, module_loader)
       expect(effective_paths.size).to be_eql(3)
       # 4x
       expect(effective_paths[0].generic_path).to be_eql(File.join(module_dir, 'lib', 'puppet', 'functions'))
       # 3x
       expect(effective_paths[1].generic_path).to be_eql(File.join(module_dir, 'lib', 'puppet','parser', 'functions'))
       # .pp
       expect(effective_paths[2].generic_path).to be_eql(File.join(module_dir, 'functions'))
    end

    it 'module loader has smart-paths that prunes unavailable paths' do
      module_dir = dir_containing('testmodule', {'functions' => {'foo.pp' => 'function foo() { yay }'} })
      # Must have a File/Path based loader to talk to
      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, 'testmodule', module_dir, 'test1')
      effective_paths = module_loader.smart_paths.effective_paths(:function)
      expect(effective_paths.size).to be_eql(1)
      expect(effective_paths[0].generic_path).to be_eql(File.join(module_dir, 'functions'))
      expect(module_loader.path_index.size).to be_eql(1)
      expect(module_loader.path_index.include?(File.join(module_dir, 'functions', 'foo.pp'))).to be(true)
    end

    it 'all function smart-paths produces entries if they exist' do
      module_dir = dir_containing('testmodule', {
        'functions' => {'foo.pp' => 'function foo() { yay }'},
        'lib' => {
          'puppet' => {
            'functions' => {'foo4x.rb' => 'ignored in this test'},
            'parser' => {
              'functions' => {'foo3x.rb' => 'ignored in this test'},
            }
          }}})
      # Must have a File/Path based loader to talk to
      module_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, 'testmodule', module_dir, 'test1')
      effective_paths = module_loader.smart_paths.effective_paths(:function)
      expect(effective_paths.size).to eq(3)
      expect(module_loader.path_index.size).to eq(3)
      path_index = module_loader.path_index
      expect(path_index.include?(File.join(module_dir, 'functions', 'foo.pp'))).to eq(true)
      expect(path_index.include?(File.join(module_dir, 'lib', 'puppet', 'functions', 'foo4x.rb'))).to eq(true)
      expect(path_index.include?(File.join(module_dir, 'lib', 'puppet', 'parser', 'functions', 'foo3x.rb'))).to eq(true)
    end
  end

end
