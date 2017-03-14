#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

module Puppet::Pops
module Resource
describe "Puppet::Pops::Resource" do
  include PuppetSpec::Compiler

  let!(:pp_parser) { Parser::EvaluatingParser.new }
  let(:loader) { Loader::BaseLoader.new(nil, 'type_parser_unit_test_loader') }
  let(:factory) { TypeFactory }

  context 'when creating resources' do
    let!(:resource_type) { ResourceTypeImpl._pcore_type }

    it 'can create an instance of a ResourceType' do
      code = <<-CODE
        $rt = Puppet::Resource::ResourceType3.new('notify', [], [Puppet::Resource::Param.new(String, 'message')])
        assert_type(Puppet::Resource::ResourceType3, $rt)
        notice('looks like we made it')
      CODE
      rt = nil
      notices = eval_and_collect_notices(code) do |scope, _|
        rt = scope['rt']
      end
      expect(notices).to eq(['looks like we made it'])
      expect(rt).to be_a(ResourceTypeImpl)
      expect(rt.valid_parameter?(:nonesuch)).to be_falsey
      expect(rt.valid_parameter?(:message)).to be_truthy
      expect(rt.valid_parameter?(:loglevel)).to be_truthy
    end
  end


  context 'when used with capability resource with producers/consumers' do
    include PuppetSpec::Files

    let!(:env_name) { 'spec' }
    let!(:env_dir) { tmpdir('environments') }
    let!(:populated_env_dir) do
      dir_contained_in(env_dir, env_name => {
        '.resource_types' => {
          'capability.pp' => <<-PUPPET
            Puppet::Resource::ResourceType3.new(
              'capability',
              [],
              [Puppet::Resource::Param(Any, 'name', true)],
              { /(.*)/ => ['name'] },
              true,
              true)
        PUPPET
        },
        'modules' => {
          'test' => {
            'lib' => {
              'puppet' => {
                'type' => { 'capability.rb' => <<-RUBY
                  Puppet::Type.newtype(:capability, :is_capability => true) do
                    newparam :name, :namevar => true
                    raise Puppet::Error, 'Ruby resource was loaded'
                  end
                RUBY
                }
              }
            }
          }
        }
      })
    end

    let!(:code) { <<-PUPPET }
      define producer() {
        notify { "producer":}
      }

      define consumer() {
        notify { $title:}
      }

      Producer produces Capability {}

      Consumer consumes Capability {}

      producer {x: export => Capability[cap]}
      consumer {x: consume => Capability[cap]}
      consumer {y: require => Capability[cap]}
    PUPPET

    let(:environments) { Puppet::Environments::Directories.new(populated_env_dir, []) }
    let(:env) { Puppet::Node::Environment.create(:'spec', [File.join(env_dir, 'spec', 'modules')]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }
    around(:each) do |example|
      Puppet[:environment] = env_name
      Puppet.override(:environments => environments, :current_environment => env) do
        example.run
      end
      Puppet::Type.rmtype(:capability)
    end

    it 'does not load the Ruby resource' do
      expect { compile_to_catalog(code, node) }.not_to raise_error
    end
  end
end
end
end
