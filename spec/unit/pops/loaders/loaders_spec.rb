require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

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
    tn = Puppet::Pops::Loader::TypedName.new(:function, '::foo::bar')
    expect(tn.frozen?).to be_truthy
    expect(tn.type).to eq(:function)
    expect(tn.name_parts).to eq(['foo', 'bar'])
    expect(tn.name).to eq('foo::bar')
    expect(tn.qualified?).to be_truthy
  end

  it 'TypedName converts name to lower case' do
    tn = Puppet::Pops::Loader::TypedName.new(:type, '::Foo::Bar')
    expect(tn.name_parts).to eq(['foo', 'bar'])
    expect(tn.name).to eq('foo::bar')
  end

  it 'TypedName is case insensitive' do
    expect(Puppet::Pops::Loader::TypedName.new(:type, '::Foo::Bar')).to eq(Puppet::Pops::Loader::TypedName.new(:type, '::foo::bar'))
  end
end

describe 'loaders' do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:module_without_metadata) { File.join(config_dir('wo_metadata_module'), 'modules') }
  let(:module_without_lib) { File.join(config_dir('module_no_lib'), 'modules') }
  let(:mix_4x_and_3x_functions) { config_dir('mix_4x_and_3x_functions') }
  let(:module_with_metadata) { File.join(config_dir('single_module'), 'modules') }
  let(:dependent_modules_with_metadata) { config_dir('dependent_modules_with_metadata') }
  let(:no_modules) { config_dir('no_modules') }
  let(:user_metadata_path) { File.join(dependent_modules_with_metadata, 'modules/user/metadata.json') }
  let(:usee_metadata_path) { File.join(dependent_modules_with_metadata, 'modules/usee/metadata.json') }
  let(:usee2_metadata_path) { File.join(dependent_modules_with_metadata, 'modules/usee2/metadata.json') }

  let(:empty_test_env) { environment_for() }

  # Loaders caches the puppet_system_loader, must reset between tests
  before(:each) { Puppet::Pops::Loaders.clear() }

  context 'when loading pp resource types using auto loading' do
    let(:pp_resources) { config_dir('pp_resources') }
    let(:environments) { Puppet::Environments::Directories.new(my_fixture_dir, []) }
    let(:env) { Puppet::Node::Environment.create(:'pp_resources', [File.join(pp_resources, 'modules')]) }
    let(:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new("test", :environment => env)) }
    let(:loader) { Puppet::Pops::Loaders.loaders.find_loader(nil) }
    around(:each) do |example|
      Puppet.override(:environments => environments) do
        Puppet.override(:loaders => compiler.loaders) do
          example.run
        end
      end
    end

    it 'finds a resource type that resides under <environment root>/.resource_types' do
      rt = loader.load(:resource_type_pp, 'myresource')
      expect(rt).to be_a(Puppet::Pops::Resource::ResourceTypeImpl)
    end

    it 'does not allow additional logic in the file' do
      expect{loader.load(:resource_type_pp, 'addlogic')}.to raise_error(ArgumentError, /it has additional logic/)
    end

    it 'does not allow creation of classes other than Puppet::Resource::ResourceType3' do
      expect{loader.load(:resource_type_pp, 'badcall')}.to raise_error(ArgumentError, /no call to Puppet::Resource::ResourceType3.new found/)
    end

    it 'does not allow creation of other types' do
      expect{loader.load(:resource_type_pp, 'wrongname')}.to raise_error(ArgumentError, /produced resource type with the wrong name, expected 'wrongname', actual 'notwrongname'/)
    end

    it 'errors with message about empty file for files that contain no logic' do
      expect{loader.load(:resource_type_pp, 'empty')}.to raise_error(ArgumentError, /it is empty/)
    end
  end

  it 'creates a puppet_system loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)
    expect(loaders.puppet_system_loader()).to be_a(Puppet::Pops::Loader::ModuleLoaders::FileBased)
  end

  it 'creates an environment loader' do
    loaders = Puppet::Pops::Loaders.new(empty_test_env)

    expect(loaders.public_environment_loader()).to be_a(Puppet::Pops::Loader::SimpleEnvironmentLoader)
    expect(loaders.public_environment_loader().to_s).to eql("(SimpleEnvironmentLoader 'environment')")
    expect(loaders.private_environment_loader()).to be_a(Puppet::Pops::Loader::DependencyLoader)
    expect(loaders.private_environment_loader().to_s).to eql("(DependencyLoader 'environment private' [])")
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
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns ''
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT

      env = environment_for(File.join(dependent_modules_with_metadata, 'modules'))
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('user')
      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")

      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
    end
  end

  context 'when loading from a module with metadata' do
    let(:env) { environment_for(File.join(dependent_modules_with_metadata, 'modules')) }
    let(:scope) { Puppet::Parser::Compiler.new(Puppet::Node.new("test", :environment => env)).newscope(nil) }

    let(:environmentpath) { my_fixture_dir }
    let(:node) { Puppet::Node.new('test', :facts => Puppet::Node::Facts.new('facts', {}), :environment => 'dependent_modules_with_metadata') }
    let(:compiler) { Puppet::Parser::Compiler.new(node) }

    let(:user_metadata) {
      {
        'name' => 'test-user',
        'author' =>  'test',
        'description' =>  '',
        'license' =>  '',
        'source' =>  '',
        'version' =>  '1.0.0',
        'dependencies' =>  []
      }
    }

    def compile_and_get_notifications(code)
      Puppet[:code] = code
      catalog = block_given? ? compiler.compile { |c| yield(compiler.topscope); c } : compiler.compile
      catalog.resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
    end

    around(:each) do |example|
      # Initialize settings to get a full compile as close as possible to a real
      # environment load
      Puppet.settings.initialize_global_settings

      # Initialize loaders based on the environmentpath. It does not work to
      # just set the setting environmentpath for some reason - this achieves the same:
      # - first a loader is created, loading directory environments from the fixture (there is
      # one environment, 'sample', which will be loaded since the node references this
      # environment by name).
      # - secondly, the created env loader is set as 'environments' in the puppet context.
      #
      environments = Puppet::Environments::Directories.new(environmentpath, [])
      Puppet.override(:environments => environments) do
        example.run
      end
    end

    it 'all dependent modules are visible' do
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'}, { 'name' => 'test-usee2'} ]).to_pson
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('user')
      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")

      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller2')).value
      expect(function.call({})).to eql("usee2::callee() was told 'passed value' + I am user::caller2()")
    end

    it 'all other modules are visible when tasks are enabled' do
      Puppet[:tasks] = true

      env = environment_for(File.join(dependent_modules_with_metadata, 'modules'))
      loaders = Puppet::Pops::Loaders.new(env)

      moduleb_loader = loaders.private_loader_for_module('user')
      function = moduleb_loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call({})).to eql("usee::callee() was told 'passed value' + I am user::caller()")
    end

    [ 'outside a function', 'a puppet function declared under functions', 'a puppet function declared in init.pp', 'a ruby function'].each_with_index do |from, from_idx|
      [ {:from => from, :called => 'a puppet function declared under functions', :expects => "I'm the function usee::usee_puppet()"},
        {:from => from, :called => 'a puppet function declared in init.pp', :expects => "I'm the function usee::usee_puppet_init()"},
        {:from => from, :called => 'a ruby function', :expects => "I'm the function usee::usee_ruby()"} ].each_with_index do |desc, called_idx|
        case_number = from_idx * 3 + called_idx + 1
        it "can call #{desc[:called]} from #{desc[:from]} when dependency is present in metadata.json" do
          File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'} ]).to_pson
          File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
          File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
          Puppet[:code] = "$case_number = #{case_number}\ninclude ::user"
          catalog = compiler.compile
          resource = catalog.resource('Notify', "case_#{case_number}")
          expect(resource).not_to be_nil
          expect(resource['message']).to eq(desc[:expects])
        end

        it "can call #{desc[:called]} from #{desc[:from]} when no metadata is present" do
          Puppet::Module.any_instance.expects('has_metadata?').at_least_once.returns(false)
          Puppet[:code] = "$case_number = #{case_number}\ninclude ::user"
          catalog = compiler.compile
          resource = catalog.resource('Notify', "case_#{case_number}")
          expect(resource).not_to be_nil
          expect(resource['message']).to eq(desc[:expects])
        end

        it "can not call #{desc[:called]} from #{desc[:from]} if dependency is missing in existing metadata.json" do
          File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => []).to_pson
          File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
          File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
          Puppet[:code] = "$case_number = #{case_number}\ninclude ::user"
          expect { compiler.compile }.to raise_error(Puppet::Error, /Unknown function/)
        end
      end
    end

    it "a type can reference an autoloaded type alias from another module when dependency is present in metadata.json" do
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'} ]).to_pson
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['ok'])
        assert_type(Usee::Zero, 0)
        notice(ok)
      CODE
    end

    it "a type can reference an autoloaded type alias from another module when no metadata is present" do
      Puppet::Module.any_instance.expects('has_metadata?').at_least_once.returns(false)
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['ok'])
        assert_type(Usee::Zero, 0)
        notice(ok)
      CODE
    end

    it "a type can reference a type alias from another module when other module has it declared in init.pp" do
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'} ]).to_pson
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['ok'])
        include 'usee'
        assert_type(Usee::One, 1)
        notice(ok)
      CODE
    end

    it "an autoloaded type can reference an autoloaded type alias from another module when dependency is present in metadata.json" do
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'} ]).to_pson
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['ok'])
        assert_type(User::WithUseeZero, [0])
        notice(ok)
      CODE
    end

    it "an autoloaded type can reference an autoloaded type alias from another module when other module has it declared in init.pp" do
      File.stubs(:read).with(user_metadata_path, {:encoding => 'utf-8'}).returns user_metadata.merge('dependencies' => [ { 'name' => 'test-usee'} ]).to_pson
      File.stubs(:read).with(usee_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      File.stubs(:read).with(usee2_metadata_path, {:encoding => 'utf-8'}).raises Errno::ENOENT
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['ok'])
        include 'usee'
        assert_type(User::WithUseeOne, [1])
        notice(ok)
      CODE
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

  context 'when loading from an environment without modules' do
    let(:node) { Puppet::Node.new('test', :facts => Puppet::Node::Facts.new('facts', {}), :environment => 'no_modules') }

    it 'can load the same function twice with two different compilations and produce different values' do
      Puppet.settings.initialize_global_settings
      environments = Puppet::Environments::Directories.new(my_fixture_dir, [])
      Puppet.override(:environments => environments) do
        compiler = Puppet::Parser::Compiler.new(node)
        compiler.topscope['value_from_scope'] = 'first'
        catalog = compiler.compile
        expect(catalog.resource('Notify[first]')).to be_a(Puppet::Resource)

        Puppet::Pops::Loader::RubyFunctionInstantiator.expects(:create).never
        compiler = Puppet::Parser::Compiler.new(node)
        compiler.topscope['value_from_scope'] = 'second'
        catalog = compiler.compile
        expect(catalog.resource('Notify[first]')).to be_nil
        expect(catalog.resource('Notify[second]')).to be_a(Puppet::Resource)
      end
    end
  end

  context 'when calling' do
    let(:env) { environment_for(mix_4x_and_3x_functions) }
    let(:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new("test", :environment => env)) }
    let(:scope) { compiler.topscope }
    let(:loader) { compiler.loaders.private_loader_for_module('user') }

    around(:each) do |example|
      Puppet.override(:current_environment => scope.environment, :global_scope => scope, :loaders => compiler.loaders) do
        example.run
      end
    end

    it 'a 3x function in dependent module can be called from a 4x function' do
      function = loader.load_typed(typed_name(:function, 'user::caller')).value
      expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
    end

    it 'a 3x function in dependent module can be called from a puppet function' do
      function = loader.load_typed(typed_name(:function, 'user::puppetcaller')).value
      expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
    end

    it 'a 4x function can be called from a puppet function' do
      function = loader.load_typed(typed_name(:function, 'user::puppetcaller4')).value
      expect(function.call(scope)).to eql("usee::callee() got 'first' - usee::callee() got 'second'")
    end

    it 'a puppet function can be called from a 4x function' do
      function = loader.load_typed(typed_name(:function, 'user::callingpuppet')).value
      expect(function.call(scope)).to eql("Did you call to say you love me?")
    end

    it 'a 3x function can be called with caller scope propagated from a 4x function' do
      function = loader.load_typed(typed_name(:function, 'user::caller_ws')).value
      expect(function.call(scope, 'passed in scope')).to eql("usee::callee_ws() got 'passed in scope'")
    end
  end

  context 'loading' do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Puppet[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
    let(:node) { Puppet::Node.new("test", :environment => env) }
    let(:env_dir_files) {}

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    context 'non autoloaded types and functions' do
      let(:env_dir_files) {
        {
          'modules' => {
            'tstf' => {
              'manifests' => {
                'init.pp' => <<-PUPPET.unindent
                  class tstf {
                    notice(testfunc())
                  }
                  PUPPET
              }
            },
            'tstt' => {
              'manifests' => {
                'init.pp' => <<-PUPPET.unindent
                  class tstt {
                    notice(assert_type(GlobalType, 23))
                  }
                  PUPPET
              }
            }
          }
        }
      }

      it 'finds the function from a module' do
        expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eq(['hello from testfunc'])
          function testfunc() {
            'hello from testfunc'
          }
          include 'tstf'
          PUPPET
      end

      it 'finds the type from a module' do
        expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eq(['23'])
          type GlobalType = Integer
          include 'tstt'
          PUPPET
      end
    end

    context 'types' do
      let(:env_name) { 'testenv' }
      let(:environments_dir) { Puppet[:environmentpath] }
      let(:env_dir) { File.join(environments_dir, env_name) }
      let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
      let(:metadata_json) {
        <<-JSON
        {
          "name": "example/%1$s",
          "version": "0.0.2",
          "source": "git@github.com/example/example-%1$s.git",
          "dependencies": [],
          "author": "Bob the Builder",
          "license": "Apache-2.0"%2$s
        }
        JSON
      }

      let(:env_dir_files) do
        {
          'types' => {
            'c.pp' => 'type C = Integer'
          },
          'modules' => {
            'a' => {
              'manifests' => {
                'init.pp' => 'class a { notice(A::A) }'
              },
              'types' => {
                'a.pp' => 'type A::A = Variant[B::B, String]',
                'n.pp' => 'type A::N = C::C'
              },
              'metadata.json' => sprintf(metadata_json, 'a', ', "dependencies": [{ "name": "example/b" }]')
            },
            'b' => {
              'types' => {
                'b.pp' => 'type B::B = Variant[C::C, Float]',
                'x.pp' => 'type B::X = A::A'
              },
              'metadata.json' => sprintf(metadata_json, 'b', ', "dependencies": [{ "name": "example/c" }]')
            },
            'c' => {
              'types' => {
                'init_typeset.pp' => <<-PUPPET.unindent,
                  type C = TypeSet[{
                    pcore_version => '1.0.0',
                    types => {
                      C => Integer,
                      D => Float
                    }
                  }]
                  PUPPET
                'd.pp' => <<-PUPPET.unindent,
                  type C::D = TypeSet[{
                    pcore_version => '1.0.0',
                    types => {
                      X => String,
                      Y => Float
                    }
                  }]
                  PUPPET
                'd' => {
                  'y.pp' => 'type C::D::Y = Integer'
                }
              },
              'metadata.json' => sprintf(metadata_json, 'c', '')
            },
            'd' => {
              'types' => {
                'init_typeset.pp' => <<-PUPPET.unindent,
                  type D = TypeSet[{
                    pcore_version => '1.0.0',
                    types => {
                      P => Object[{}],
                      O => Object[{ parent => P }]
                    }
                  }]
                  PUPPET
              },
              'metadata.json' => sprintf(metadata_json, 'd', '')
            }
          }
        }
      end

      before(:each) do
        Puppet.push_context(:loaders => Puppet::Pops::Loaders.new(env))
      end

      after(:each) do
        Puppet.pop_context
      end

      it 'resolves types using the loader that loaded the type a -> b -> c' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('A::A', Puppet::Pops::Loaders.find_loader('a'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.name).to eql('A::A')
        type = type.resolved_type
        expect(type).to be_a(Puppet::Pops::Types::PVariantType)
        type = type.types[0]
        expect(type.name).to eql('B::B')
        type = type.resolved_type
        expect(type).to be_a(Puppet::Pops::Types::PVariantType)
        type = type.types[0]
        expect(type.name).to eql('C::C')
        type = type.resolved_type
        expect(type).to be_a(Puppet::Pops::Types::PIntegerType)
      end

      it 'will not resolve implicit transitive dependencies, a -> c' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('A::N', Puppet::Pops::Loaders.find_loader('a'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.name).to eql('A::N')
        type = type.resolved_type
        expect(type).to be_a(Puppet::Pops::Types::PTypeReferenceType)
        expect(type.type_string).to eql('C::C')
      end

      it 'will not resolve reverse dependencies, b -> a' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('B::X', Puppet::Pops::Loaders.find_loader('b'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.name).to eql('B::X')
        type = type.resolved_type
        expect(type).to be_a(Puppet::Pops::Types::PTypeReferenceType)
        expect(type.type_string).to eql('A::A')
      end

      it 'does not resolve init_typeset when more qualified type is found in typeset' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('C::D::X', Puppet::Pops::Loaders.find_loader('c'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.resolved_type).to be_a(Puppet::Pops::Types::PStringType)
      end

      it 'defined TypeSet type shadows type defined inside of TypeSet' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('C::D', Puppet::Pops::Loaders.find_loader('c'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeSetType)
      end

      it 'parent name search does not traverse parent loaders' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('C::C', Puppet::Pops::Loaders.find_loader('c'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.resolved_type).to be_a(Puppet::Pops::Types::PIntegerType)
      end

      it 'global type defined in environment trumps modules init_typeset type' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('C', Puppet::Pops::Loaders.find_loader('c'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.resolved_type).to be_a(Puppet::Pops::Types::PIntegerType)
      end

      it 'hit on qualified name trumps hit on typeset using parent name + traversal' do
        type = Puppet::Pops::Types::TypeParser.singleton.parse('C::D::Y', Puppet::Pops::Loaders.find_loader('c'))
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.resolved_type).to be_a(Puppet::Pops::Types::PIntegerType)
      end

      it 'hit on qualified name and subsequent hit in typeset when searching for other name causes collision' do
        l = Puppet::Pops::Loaders.find_loader('c')
        p = Puppet::Pops::Types::TypeParser.singleton
        p.parse('C::D::Y', l)
        expect { p.parse('C::D::X', l) }.to raise_error(/Attempt to redefine entity 'http:\/\/puppet.com\/2016.1\/runtime\/type\/c::d::y'/)
      end

      it 'hit in typeset using parent name and subsequent search that would cause hit on fqn does not cause collision (fqn already loaded from typeset)' do
        l = Puppet::Pops::Loaders.find_loader('c')
        p = Puppet::Pops::Types::TypeParser.singleton
        p.parse('C::D::X', l)
        type = p.parse('C::D::Y', l)
        expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
        expect(type.resolved_type).to be_a(Puppet::Pops::Types::PFloatType)
      end

      it 'loads an object type from a typeset that references another type defined in the same typeset' do
        l = Puppet::Pops::Loaders.find_loader('d').private_loader
        p = Puppet::Pops::Types::TypeParser.singleton
        type = p.parse('D::O', l)
        expect(type).to be_a(Puppet::Pops::Types::PObjectType)
        expect(type.resolved_parent).to be_a(Puppet::Pops::Types::PObjectType)
      end
    end
  end

  def environment_for(*module_paths)
    Puppet::Node::Environment.create(:'*test*', module_paths)
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::TypedName.new(type, name)
  end

  def config_dir(config_name)
    my_fixture(config_name)
  end
end
