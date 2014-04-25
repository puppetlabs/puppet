require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/pops'
require 'puppet/loaders'

describe 'loaders' do
  include PuppetSpec::Files

  def config_dir(config_name)
    my_fixture(config_name)
  end

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
    expect(loaders.public_environment_loader().class).to be(Puppet::Pops::Loader::SimpleEnvironmentLoader)
    # The default name of the enironment is '*root*', and the loader should identify itself that way
    expect(loaders.public_environment_loader().to_s).to eql("(SimpleEnvironmentLoader 'environment:*root*')")

    expect(loaders.private_environment_loader().class).to be(Puppet::Pops::Loader::DependencyLoader)
    expect(loaders.private_environment_loader().to_s).to eql("(DependencyLoader 'environment' [])")
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

  context 'loading from path with single module' do
    before do
      env = Puppet::Node::Environment.create(:'*test*', [File.join(config_dir('single_module'), 'modules')], '')
      overrides = {
        :current_environment => env
      }
      Puppet.push_context(overrides, "single-module-test-loaders")
    end

    after do
      Puppet.pop_context()
    end

    it 'can load from a module path' do
      loaders = Puppet::Pops::Loaders.new()
      Puppet.override({:loaders => loaders}, 'testcase') do
        modulea_loader = loaders.public_loader_for_module('modulea')
        expect(modulea_loader.class).to eql(Puppet::Pops::Loader::ModuleLoaders::FileBased)

        function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
        expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
        expect(function.class.name).to eq('rb_func_a')

        function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value
        expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
        expect(function.class.name).to eq('modulea::rb_func_a')
      end
    end
  end

  context 'loading from path with two module, one without meta-data' do
    before do
      module_path = [File.join(config_dir('single_module'), 'modules'), File.join(config_dir('wo_metadata_module'), 'modules')]
      env = Puppet::Node::Environment.create(:'*test*', module_path, '')
      overrides = {
        :current_environment => env,
      }
      Puppet.push_context(overrides, "two-modules-test-loaders")
    end

    after do
      Puppet.pop_context()
    end

    it 'can load from module with metadata' do
      loaders = Puppet::Pops::Loaders.new
      Puppet.override({:loaders => loaders}, 'testcase') do
        modulea_loader = loaders.public_loader_for_module('modulea')
        expect(modulea_loader.class).to eql(Puppet::Pops::Loader::ModuleLoaders::FileBased)

        function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
        expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
        expect(function.class.name).to eq('rb_func_a')

        function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value
        expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
        expect(function.class.name).to eq('modulea::rb_func_a')
      end
    end

    it 'can load from module with metadata' do
      loaders = Puppet::Pops::Loaders.new
      Puppet.override({:loaders => loaders}, 'testcase') do
        moduleb_loader = loaders.public_loader_for_module('moduleb')
        expect(moduleb_loader.class).to eql(Puppet::Pops::Loader::ModuleLoaders::FileBased)

        function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value
        expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
        expect(function.class.name).to eq('moduleb::rb_func_b')
      end
    end

    it 'module without metadata has all modules visible' do
      loaders = Puppet::Pops::Loaders.new
      Puppet.override({:loaders => loaders}, 'testcase') do
        moduleb_loader = loaders.private_loader_for_module('moduleb')

        function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value
        result = function.call({})
        expect(result).to eql("I am modulea::rb_func_a() + I am moduleb::rb_func_b()")
      end
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end
