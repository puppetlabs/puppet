require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/pops'
require 'puppet/loaders'

describe 'loaders' do
  include PuppetSpec::Files

  let(:empty_test_env) { Puppet::Node::Environment.create(:testing, []) }

  def config_dir(config_name)
    my_fixture(config_name)
  end

  # Loaders caches the puppet_system_loader, must reset between tests
  #
  before(:each) { Puppet::Pops::Loaders.clear() }

  it 'creates a puppet_system loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)
    expect(loaders.puppet_system_loader()).to be_a(Puppet::Pops::Loader::ModuleLoaders::FileBased)
  end

  it 'creates an environment loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)

    expect(loaders.public_environment_loader()).to be_a(Puppet::Pops::Loader::SimpleEnvironmentLoader)
    expect(loaders.public_environment_loader().to_s).to eql("(SimpleEnvironmentLoader 'environment:testing')")
    expect(loaders.private_environment_loader()).to be_a(Puppet::Pops::Loader::DependencyLoader)
    expect(loaders.private_environment_loader().to_s).to eql("(DependencyLoader 'environment' [])")
  end

  it 'can load 3x system functions' do
    Puppet[:biff] = true
    loaders = Puppet::Pops::Loaders.new(empty_test_env)
    puppet_loader = loaders.puppet_system_loader()

    function = puppet_loader.load_typed(typed_name(:function, 'sprintf')).value

    expect(function.class.name).to eq('sprintf')
    expect(function).to be_a(Puppet::Functions::Function)
  end

  it 'can load from a module path with a single module using the qualified or unqualified name' do
    env = Puppet::Node::Environment.create(:'*test*', [File.join(config_dir('single_module'), 'modules')], '')
    loaders = Puppet::Pops::Loaders.new(env)
    Puppet.override({:loaders => loaders}, 'testcase') do
      modulea_loader = loaders.public_loader_for_module('modulea')

      unqualified_function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
      qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value

      expect(unqualified_function).to be_a(Puppet::Functions::Function)
      expect(qualified_function).to be_a(Puppet::Functions::Function)
      expect(unqualified_function.class.name).to eq('rb_func_a')
      expect(qualified_function.class.name).to eq('modulea::rb_func_a')
    end
  end

  context 'loading from path with two module, one without meta-data' do
    let(:env) { Puppet::Node::Environment.create(:'*test*', [File.join(config_dir('single_module'), 'modules'), File.join(config_dir('wo_metadata_module'), 'modules')], '')}

    it 'can load from module with metadata' do
      loaders = Puppet::Pops::Loaders.new(env)
      Puppet.override({:loaders => loaders}, 'testcase') do
        modulea_loader = loaders.public_loader_for_module('modulea')

        unqualified_function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
        qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value

        expect(unqualified_function).to be_a(Puppet::Functions::Function)
        expect(qualified_function).to be_a(Puppet::Functions::Function)
        expect(unqualified_function.class.name).to eq('rb_func_a')
        expect(qualified_function.class.name).to eq('modulea::rb_func_a')
      end
    end

    it 'can load from module without metadata' do
      loaders = Puppet::Pops::Loaders.new(env)
      Puppet.override({:loaders => loaders}, 'testcase') do
        moduleb_loader = loaders.public_loader_for_module('moduleb')

        function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

        expect(function).to be_a(Puppet::Functions::Function)
        expect(function.class.name).to eq('moduleb::rb_func_b')
      end
    end

    it 'module without metadata has all modules visible' do
      loaders = Puppet::Pops::Loaders.new(env)
      Puppet.override({:loaders => loaders}, 'testcase') do
        moduleb_loader = loaders.private_loader_for_module('moduleb')
        function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

        expect(function.call({})).to eql("I am modulea::rb_func_a() + I am moduleb::rb_func_b()")
      end
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end
