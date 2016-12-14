require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/pops'

describe 'when calling' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  let(:global_dir) { tmpdir('global') }
  let(:env_config) { {} }
  let(:global_files) do
    {
      'hiera.yaml' => <<-YAML.unindent,
        ---
        :backends:
          - yaml
          - custom
        :yaml:
          :datadir: #{global_dir}/hieradata
        :hierarchy:
          - first
          - second
        YAML
      'ruby_stuff' => {
        'hiera' => {
          'backend' => {
            'custom_backend.rb' => <<-RUBY.unindent
                    class Hiera::Backend::Custom_backend
                      def lookup(key, scope, order_override, resolution_type, context)
                        case key
                        when 'datasources'
                          Hiera::Backend.datasources(scope, order_override) { |source| source }
                        else
                          throw :no_such_key
                        end
                      end
                    end
              RUBY
          }
        }
      },
      'hieradata' => {
        'first.yaml' => <<-YAML.unindent,
                ---
                a: first a
                class_name: "-- %{calling_class} --"
                class_path: "-- %{calling_class_path} --"
                module: "-- %{calling_module} --"
                mod_name: "-- %{module_name} --"
                b:
                  b1: first b1
                  b2: first b2
                fbb:
                  - mod::foo
                  - mod::bar
                  - mod::baz
                empty_array: []
          YAML
        'second.yaml' => <<-YAML.unindent,
          ---
          a: second a
          b:
            b1: second b1
            b3: second b3
          YAML
        'the_override.yaml' => <<-YAML.unindent
          ---
          key: foo_result
          YAML
      },
      'environments' => {
        'test' => {
          'modules' => {
            'mod' => {
              'manifests' => {
                'foo.pp' => <<-PUPPET.unindent,
                    class mod::foo {
                      notice(hiera('class_name'))
                      notice(hiera('class_path'))
                      notice(hiera('module'))
                      notice(hiera('mod_name'))
                    }
                  PUPPET
                'bar.pp' => <<-PUPPET.unindent,
                    class mod::bar {}
                  PUPPET
                'baz.pp' => <<-PUPPET.unindent
                     class mod::baz {}
                  PUPPET
              },
              'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                YAML
              'data' => {
                 'common.yaml' => <<-YAML.unindent
                    mod::c: mod::c (from module)
                  YAML
              }
            }
          }
        }
      }
    }
  end

  let(:env_dir) { File.join(global_dir, 'environments') }
  let(:env) { Puppet::Node::Environment.create(:test, [File.join(env_dir, 'test', 'modules')]) }
  let(:environments) { Puppet::Environments::Directories.new(env_dir, []) }
  let(:node) { Puppet::Node.new('test_hiera', :environment => env) }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:the_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'hiera') }

  before(:each) do
    Puppet.settings[:codedir] = global_dir
    Puppet.settings[:hiera_config] = File.join(global_dir, 'hiera.yaml')
  end

  around(:each) do |example|
    # Faking the load path to enable 'require' to load from 'ruby_stuff'. It removes the need for a static fixture
    # for the custom backend
    dir_contained_in(global_dir, DeepMerge.deep_merge!(global_files, { 'environments' => { 'test' => env_config } } ))
    $LOAD_PATH.unshift(File.join(global_dir, 'ruby_stuff'))
    begin
      Puppet.override(:environments => environments, :current_environment => env) do
        example.run
      end
    ensure
      Hiera::Backend.send(:remove_const, :Custom_backend) if Hiera::Backend.const_defined?(:Custom_backend)
      $LOAD_PATH.shift
    end
  end

  def with_scope(code = 'undef')
    result = nil
    Puppet[:code] = 'undef'
    compiler.topscope['environment'] = 'test'
    compiler.compile do |catalog|
      result = yield(compiler.topscope)
      catalog
    end
    result
  end

  def func(*args, &block)
    with_scope { |scope| the_func.call(scope, *args, &block) }
  end

  context 'hiera' do
    it 'should require a key argument' do
      expect { func([]) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { func('badkey') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'badkey'/)
    end

    it 'should use the "first" merge strategy' do
      expect(func('a')).to eql('first a')
    end

    it 'should not find data in module' do
      expect(func('mod::c', 'default mod::c')).to eql('default mod::c')
    end

    it 'should propagate optional override' do
      ovr = 'the_override'
      expect(func('key', nil, ovr)).to eql('foo_result')
    end

    it 'backend data sources, including optional overrides, are propagated to custom backend' do
      expect(func('datasources', nil, 'the_override')).to eql(['the_override', 'first', 'second'])
    end

    it 'a hiera v3 scope is used' do
      expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['-- testing --', '-- mod::foo --', '-- mod/foo --', '-- mod --', '-- mod --'])
      class testing () {
         notice(hiera('class_name'))
      }
      include testing
      include mod::foo
      PUPPET
    end

    it 'should return default value nil when key is not found' do
       expect(func('foo', nil)).to be_nil
    end

    it "should return default value '' when key is not found" do
      expect(func('foo', '')).to eq('')
    end

    it 'should use default block' do
      expect(func('foo') { |k| "default for key '#{k}'" }).to eql("default for key 'foo'")
    end

    it 'should propagate optional override when combined with default block' do
      ovr = 'the_override'
      with_scope do |scope|
        expect(the_func.call(scope, 'key', ovr) { |k| "default for key '#{k}'" }).to eql('foo_result')
        expect(the_func.call(scope, 'foo.bar', ovr) { |k| "default for key '#{k}'" }).to eql("default for key 'foo.bar'")
      end
    end

    context 'with environment with configured data provider' do
      let(:env_config) {
        {
          'hiera.yaml' => <<-YAML.unindent,
             ---
             version: 5
             YAML
          'data' => {
            'common.yaml' => <<-YAML.unindent
              ---
              a: a (from environment)
              e: e (from environment)
              YAML
          }
        }
      }

      it 'should find data globally' do
        expect(func('a')).to eql('first a')
      end

      it 'should find data in the environment' do
        expect(func('e')).to eql('e (from environment)')
      end

      it 'should find data in module' do
        expect(func('mod::c')).to eql('mod::c (from module)')
      end
    end
  end

  context 'hiera_array' do
    let(:the_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'hiera_array') }

    it 'should require a key argument' do
      expect { func([]) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { func('badkey') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'badkey'/)
    end

    it 'should use the array resolution_type' do
      expect(func('fbb', {'fbb' => 'foo_result'})).to eql(%w[mod::foo mod::bar mod::baz])
    end

    it 'should use default block' do
      expect(func('foo') { |k| ['key', k] }).to eql(%w[key foo])
    end
  end

  context 'hiera_hash' do
    let(:the_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'hiera_hash') }

    it 'should require a key argument' do
      expect { func([]) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { func('badkey') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'badkey'/)
    end

    it 'should use the hash resolution_type' do
      expect(func('b', {'b' => 'foo_result'})).to eql({ 'b1' => 'first b1', 'b2' => 'first b2', 'b3' => 'second b3'})
    end

    it 'should use default block' do
      expect(func('foo') { |k| {'key' => k} }).to eql({'key' => 'foo'})
    end
  end

  context 'hiera_include' do
    let(:the_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'hiera_include') }

    it 'should require a key argument' do
      expect { func([]) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { func('badkey') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'badkey'/)
    end

    it 'should use the array resolution_type to include classes' do
      expect(func('fbb').map { |c| c.class_name }).to eql(%w[mod::foo mod::bar mod::baz])
    end

    it 'should not raise an error if the resulting hiera lookup returns an empty array' do
      expect { func('empty_array') }.to_not raise_error
    end

    it 'should use default block array to include classes' do
      expect(func('foo') { |k| ['mod::bar', "mod::#{k}"] }.map { |c| c.class_name }).to eql(%w[mod::bar mod::foo])
    end
  end
end
