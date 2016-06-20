require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Serialization
describe 'RGen' do
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }
  let(:loader) { loaders.find_loader(nil) }

  around :each do |example|
    Puppet.override(:loaders => loaders, :current_environment => env) do
      example.run
    end
  end

  context 'TypeGenerator' do
    let(:generator) { RGen::TypeGenerator.new }
    it 'generates TypeSet from a module that represents an ECore package' do
      generator.generate_type_set('Pops::Bindings', Puppet::Pops::Binder::Bindings, loader)
    end
  end
end
end
end
