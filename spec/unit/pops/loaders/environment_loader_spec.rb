require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'Environment loader' do
  include PuppetSpec::Files

  let(:env_name) { 'spec' }
  let(:code_dir) { Puppet[:environmentpath] }
  let(:env_dir) { File.join(code_dir, env_name) }
  let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_code_dir, env_name, 'modules')]) }
  let(:populated_code_dir) do
    dir_contained_in(code_dir, env_name => env_content)
    PuppetSpec::Files.record_tmp(env_dir)
    code_dir
  end

  let(:env_content) {
    {
      'lib' => {
        'puppet' => {
          'functions' => {
            'ruby_foo.rb' => <<-RUBY.unindent,
              Puppet::Functions.create_function(:ruby_foo) do
                def ruby_foo()
                  'ruby_foo'
                end
              end
              RUBY
            'environment' => {
              'ruby_foo.rb' => <<-RUBY.unindent
                Puppet::Functions.create_function(:'environment::ruby_foo') do
                  def ruby_foo()
                    'environment::ruby_foo'
                  end
                end
                RUBY
            },
            'someother' => {
              'ruby_foo.rb' => <<-RUBY.unindent
                Puppet::Functions.create_function(:'someother::ruby_foo') do
                  def ruby_foo()
                    'someother::ruby_foo'
                  end
                end
                RUBY
            },
          }
        }
      },
      'functions' => {
        'puppet_foo.pp' => <<-PUPPET.unindent,
          function puppet_foo() {
            'puppet_foo'
          }
          PUPPET
        'environment' => {
          'puppet_foo.pp' => <<-PUPPET.unindent,
            function environment::puppet_foo() {
              'environment::puppet_foo'
            }
            PUPPET
        },
        'someother' => {
          'puppet_foo.pp' => <<-PUPPET.unindent,
            function somether::puppet_foo() {
              'someother::puppet_foo'
            }
            PUPPET
        }
      },
      'types' => {
        'footype.pp' => <<-PUPPET.unindent,
          type FooType = Enum['foo', 'bar', 'baz']
          PUPPET
        'environment' => {
          'footype.pp' => <<-PUPPET.unindent,
            type Environment::FooType = Integer[0,9]
            PUPPET
        },
        'someother' => {
          'footype.pp' => <<-PUPPET.unindent,
            type SomeOther::FooType = Float[0.0,9.0]
            PUPPET
        }
      }
    }
  }

  before(:each) do
    Puppet.push_context(:loaders => Puppet::Pops::Loaders.new(env))
  end

  after(:each) do
    Puppet.pop_context
  end

  def load_or_nil(type, name)
    found = Puppet::Pops::Loaders.find_loader(nil).load_typed(Puppet::Pops::Loader::TypedName.new(type, name))
    found.nil? ? nil : found.value
  end

  context 'loading a Ruby function' do
    it 'loads from global name space' do
      function = load_or_nil(:function, 'ruby_foo')
      expect(function).not_to be_nil

      expect(function.class.name).to eq('ruby_foo')
      expect(function).to be_a(Puppet::Functions::Function)
    end

    it 'loads from environment name space' do
      function = load_or_nil(:function, 'environment::ruby_foo')
      expect(function).not_to be_nil

      expect(function.class.name).to eq('environment::ruby_foo')
      expect(function).to be_a(Puppet::Functions::Function)
    end

    it 'fails to load from namespaces other than global or environment' do
      function = load_or_nil(:function, 'someother::ruby_foo')
      expect(function).to be_nil
    end
  end

  context 'loading a Puppet function' do
    it 'loads from global name space' do
      function = load_or_nil(:function, 'puppet_foo')
      expect(function).not_to be_nil

      expect(function.class.name).to eq('puppet_foo')
      expect(function).to be_a(Puppet::Functions::PuppetFunction)
    end

    it 'loads from environment name space' do
      function = load_or_nil(:function, 'environment::puppet_foo')
      expect(function).not_to be_nil

      expect(function.class.name).to eq('environment::puppet_foo')
      expect(function).to be_a(Puppet::Functions::PuppetFunction)
    end

    it 'fails to load from namespaces other than global or environment' do
      function = load_or_nil(:function, 'someother::puppet_foo')
      expect(function).to be_nil
    end
  end

  context 'loading a Puppet type' do
    it 'loads from global name space' do
      type = load_or_nil(:type, 'footype')
      expect(type).not_to be_nil

      expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
      expect(type.name).to eq('FooType')
    end

    it 'loads from environment name space' do
      type = load_or_nil(:type, 'environment::footype')
      expect(type).not_to be_nil

      expect(type).to be_a(Puppet::Pops::Types::PTypeAliasType)
      expect(type.name).to eq('Environment::FooType')
    end

    it 'fails to load from namespaces other than global or environment' do
      type = load_or_nil(:type, 'someother::footype')
      expect(type).to be_nil
    end
  end
end
