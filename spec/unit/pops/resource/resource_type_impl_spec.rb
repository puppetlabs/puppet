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
end
end
end
