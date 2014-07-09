require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/pops'
require 'puppet/loaders'

describe 'loader helper classes' do
  it 'NamedEntry holds values and is frozen' do
    ne = Puppet::Pops::Loader::Loader::NamedEntry.new('name', 'value', 'origin')
    expect(ne.frozen?).to be_true
    expect(ne.typed_name).to eql('name')
    expect(ne.origin).to eq('origin')
    expect(ne.value).to eq('value')
  end

  it 'TypedName holds values and is frozen' do
    tn = Puppet::Pops::Loader::Loader::TypedName.new(:function, '::foo::bar')
    expect(tn.frozen?).to be_true
    expect(tn.type).to eq(:function)
    expect(tn.name_parts).to eq(['foo', 'bar'])
    expect(tn.name).to eq('foo::bar')
    expect(tn.qualified).to be_true
  end
end

describe 'loaders' do
  include PuppetSpec::Files

  let(:module_without_metadata) { File.join(config_dir('wo_metadata_module'), 'modules') }
  let(:module_with_metadata) { File.join(config_dir('single_module'), 'modules') }
  let(:dependent_modules_with_metadata) { config_dir('dependent_modules_with_metadata') }
  let(:empty_test_env) { environment_for() }

  # Loaders caches the puppet_system_loader, must reset between tests
  before(:each) { Puppet::Pops::Loaders.clear() }

  it 'creates a puppet_system loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)
    expect(loaders.puppet_system_loader()).to be_a(Puppet::Pops::Loader::ModuleLoaders::FileBased)
  end

  it 'creates an environment loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)

    expect(loaders.public_environment_loader()).to be_a(Puppet::Pops::Loader::SimpleEnvironmentLoader)
    expect(loaders.public_environment_loader().to_s).to eql("(SimpleEnvironmentLoader 'environment:*test*')")
    expect(loaders.private_environment_loader()).to be_a(Puppet::Pops::Loader::DependencyLoader)
    expect(loaders.private_environment_loader().to_s).to eql("(DependencyLoader 'environment' [])")
  end

  it 'can load a function using a qualified or unqualified name from a module with metadata' do
    loaders = Puppet::Pops::Loaders.new(environment_for(module_with_metadata))
    modulea_loader = loaders.public_loader_for_module('modulea')

    unqualified_function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
    qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value

    expect(unqualified_function).to be_a(Puppet::Functions::Function)
    expect(qualified_function).to be_a(Puppet::Functions::Function)
    expect(unqualified_function.class.name).to eq('rb_func_a')
    expect(qualified_function.class.name).to eq('modulea::rb_func_a')
  end

  it 'can load a function with a qualified name from module without metadata' do
    loaders = Puppet::Pops::Loaders.new(environment_for(module_without_metadata))

    moduleb_loader = loaders.public_loader_for_module('moduleb')
    function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

    expect(function).to be_a(Puppet::Functions::Function)
    expect(function.class.name).to eq('moduleb::rb_func_b')
  end

  it 'cannot load an unqualified function from a module without metadata' do
    loaders = Puppet::Pops::Loaders.new(environment_for(module_without_metadata))

    moduleb_loader = loaders.public_loader_for_module('moduleb')

    expect(moduleb_loader.load_typed(typed_name(:function, 'rb_func_b'))).to be_nil
  end

  it 'makes all other modules visible to a module without metadata' do
    env = environment_for(module_with_metadata, module_without_metadata)
    loaders = Puppet::Pops::Loaders.new(env)

    moduleb_loader = loaders.private_loader_for_module('moduleb')
    function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

    expect(function.call({})).to eql("I am modulea::rb_func_a() + I am moduleb::rb_func_b()")
  end

  it 'makes dependent modules visible to a module with metadata' do
    env = environment_for(dependent_modules_with_metadata)
    loaders = Puppet::Pops::Loaders.new(env)

    moduleb_loader = loaders.private_loader_for_module('user')
    function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value

    expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
  end

  it 'can load a function more than once from modules' do
    env = environment_for(dependent_modules_with_metadata)
    loaders = Puppet::Pops::Loaders.new(env)

    moduleb_loader = loaders.private_loader_for_module('user')
    function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
    expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")

    function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
    expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
  end

  def environment_for(*module_paths)
    Puppet::Node::Environment.create(:'*test*', module_paths, '')
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end

  def config_dir(config_name)
    my_fixture(config_name)
  end
end
