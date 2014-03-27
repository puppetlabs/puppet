require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'loaders' do
  # Loaders caches the puppet_system_loader, must reset between tests
  #
  before(:each) { Puppet::Pops::Loaders.clear() }

  it 'creates a puppet_system loader' do
    loaders = Puppet::Pops::Loaders.new()
    expect(loaders.puppet_system_loader().class).to be(Puppet::Pops::Loader::ModuleLoaders::FileBased)
  end

  it 'creates an environment loader' do
    loaders = Puppet::Pops::Loaders.new()
    # When this test is running, there is no environments dir configured, and a NullLoader is therefore used a.t.m
    expect(loaders.environment_loader().class).to be(Puppet::Pops::Loader::NullLoader)
    # The default name of the enironment is '*root*', and the loader should identify itself that way
    expect(loaders.environment_loader().to_s).to eql("(NullLoader 'environment:*root*')")
  end

  context 'when delegating 3x to 4x' do
    before(:each) { Puppet[:biff] = true }

    it 'the puppet system loader can load 3x functions' do
      loaders = Puppet::Pops::Loaders.new()
      puppet_loader = loaders.puppet_system_loader()
      function = puppet_loader.load_typed(typed_name(:function, 'sprintf')).value
      expect(function.class.name).to eq('sprintf')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end
  end

  # TODO: LOADING OF MODULES ON MODULEPATH

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end