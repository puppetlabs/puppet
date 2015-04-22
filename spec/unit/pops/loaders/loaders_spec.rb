require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/pops'
require 'puppet/loaders'

describe 'loader helper classes' do
  it 'NamedEntry holds values and is frozen' do
    ne = Puppet::Pops::Loader::Loader::NamedEntry.new('name', 'value', 'origin')
    expect(ne.frozen?).to be_truthy
    expect(ne.typed_name).to eql('name')
    expect(ne.origin).to eq('origin')
    expect(ne.value).to eq('value')
  end

  it 'TypedName holds values and is frozen' do
    tn = Puppet::Pops::Loader::Loader::TypedName.new(:function, '::foo::bar')
    expect(tn.frozen?).to be_truthy
    expect(tn.type).to eq(:function)
    expect(tn.name_parts).to eq(['foo', 'bar'])
    expect(tn.name).to eq('foo::bar')
    expect(tn.qualified?).to be_truthy
  end
end

describe 'loaders' do
  include PuppetSpec::Files

  let(:module_without_metadata) { File.join(config_dir('wo_metadata_module'), 'modules') }
  let(:module_without_lib) { File.join(config_dir('module_no_lib'), 'modules') }
  let(:mix_4x_and_3x_functions) { config_dir('mix_4x_and_3x_functions') }
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

  context 'when loading from a module' do
    it 'loads a ruby function using a qualified or unqualified name' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_with_metadata))
      modulea_loader = loaders.public_loader_for_module('modulea')

      unqualified_function = modulea_loader.load_typed(typed_name(:function, 'rb_func_a')).value
      qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::rb_func_a')).value

      expect(unqualified_function).to be_a(Puppet::Functions::Function)
      expect(qualified_function).to be_a(Puppet::Functions::Function)
      expect(unqualified_function.class.name).to eq('rb_func_a')
      expect(qualified_function.class.name).to eq('modulea::rb_func_a')
    end

    it 'loads a puppet function using a qualified name in module' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_with_metadata))
      modulea_loader = loaders.public_loader_for_module('modulea')

      qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::hello')).value

      expect(qualified_function).to be_a(Puppet::Functions::Function)
      expect(qualified_function.class.name).to eq('modulea::hello')
    end

    it 'loads a puppet function from a module without a lib directory' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_without_lib))
      modulea_loader = loaders.public_loader_for_module('modulea')

      qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::hello')).value

      expect(qualified_function).to be_a(Puppet::Functions::Function)
      expect(qualified_function.class.name).to eq('modulea::hello')
    end

    it 'loads a puppet function in a sub namespace of module' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_with_metadata))
      modulea_loader = loaders.public_loader_for_module('modulea')

      qualified_function = modulea_loader.load_typed(typed_name(:function, 'modulea::subspace::hello')).value

      expect(qualified_function).to be_a(Puppet::Functions::Function)
      expect(qualified_function.class.name).to eq('modulea::subspace::hello')
    end

    it 'loader does not add namespace if not given' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_without_metadata))

      moduleb_loader = loaders.public_loader_for_module('moduleb')

      expect(moduleb_loader.load_typed(typed_name(:function, 'rb_func_b'))).to be_nil
    end

    it 'loader allows loading a function more than once' do
      env = environment_for(dependent_modules_with_metadata)
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('user')
      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")

      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
    end
  end

  context 'when loading from a module with metadata' do
    it 'all dependent modules are visible' do
      env = environment_for(dependent_modules_with_metadata)
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('user')
      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
    end
  end

  context 'when loading from a module without metadata' do
    it 'loads a ruby function with a qualified name' do
      loaders = Puppet::Pops::Loaders.new(environment_for(module_without_metadata))

      moduleb_loader = loaders.public_loader_for_module('moduleb')
      function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

      expect(function).to be_a(Puppet::Functions::Function)
      expect(function.class.name).to eq('moduleb::rb_func_b')
    end


    it 'all other modules are visible' do
      env = environment_for(module_with_metadata, module_without_metadata)
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('moduleb')
      function = moduleb_loader.load_typed(typed_name(:function, 'moduleb::rb_func_b')).value

      expect(function.call({})).to eql("I am modulea::rb_func_a() + I am moduleb::rb_func_b()")
    end
  end

  context 'when calling' do
    let(:env) { environment_for(mix_4x_and_3x_functions) }
    let(:scope) { Puppet::Parser::Compiler.new(Puppet::Node.new("test", :environment => env)).newscope(nil) }
    let(:loader) { Puppet::Pops::Loaders.new(env).private_loader_for_module('user') }

    it 'a 3x function in dependent module can be called from a 4x function' do
      Puppet.override({ :current_environment => scope.environment, :global_scope => scope }) do
        function = loader.load_typed(typed_name(:function, 'user::caller')).value
        expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
      end
    end

    it 'a 3x function in dependent module can be called from a puppet function' do
      Puppet.override({ :current_environment => scope.environment, :global_scope => scope }) do
        function = loader.load_typed(typed_name(:function, 'user::puppetcaller')).value
        expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
      end
    end

    it 'a 4x function can be called from a puppet function' do
      Puppet.override({ :current_environment => scope.environment, :global_scope => scope }) do
        function = loader.load_typed(typed_name(:function, 'user::puppetcaller4')).value
        expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
      end
    end
    it 'a puppet function can be called from a 4x function' do
      Puppet.override({ :current_environment => scope.environment, :global_scope => scope }) do
        function = loader.load_typed(typed_name(:function, 'user::callingpuppet')).value
        expect(function.call(scope)).to eql("Did you call to say you love me?")
      end
    end

    it 'a 3x function can be called with caller scope propagated from a 4x function' do
      Puppet.override({ :current_environment => scope.environment, :global_scope => scope }) do
        function = loader.load_typed(typed_name(:function, 'user::caller_ws')).value
        expect(function.call(scope, 'passed in scope')).to eql("usee::callee_ws() got 'passed in scope'")
      end
    end
  end


  def environment_for(*module_paths)
    Puppet::Node::Environment.create(:'*test*', module_paths)
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end

  def config_dir(config_name)
    my_fixture(config_name)
  end
end
