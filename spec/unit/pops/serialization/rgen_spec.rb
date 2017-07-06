require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Serialization
describe 'RGen' do
  let!(:env) { Puppet::Node::Environment.create(:testing, []) }
  let!(:loaders) { Puppet::Pops::Loaders.new(env) }
  let!(:loader) { loaders.find_loader(nil) }

  around :each do |example|
    Puppet.override(:loaders => loaders, :current_environment => env) do
      example.run
    end
  end

  def find_parent(type, parent_name)
    p = type
    while p.is_a?(Types::PObjectType) && p.name != parent_name
      p = p.parent
    end
    expect(p).to be_a(Types::PObjectType), "did not find #{parent_name} in parent chain of #{type.name}"
    p
  end

  context 'TypeGenerator' do

    let!(:generator) { RGen::TypeGenerator.new }
    let!(:type_set) { generator.generate_type_set('PuppetSpec::Bindings', Binder::Bindings, loader) }
    let!(:bindings_classes) do
      Binder::Bindings.constants.each_with_object([]) do |n, a|
        cls = Binder::Bindings.const_get(n)
        a << cls if cls.is_a?(Class) && cls.respond_to?(:ecore)
      end
    end

    it 'generates TypeSet from a module that represents an ECore package' do
      expect(type_set).to be_a(Types::PTypeSetType)
      expect(type_set.types).not_to be_empty
      expect(type_set.types.size).to eql(bindings_classes.size)
    end

    it 'all types are in the PuppetSpec::Bindings namespace' do
      type_set.types.values.each {|type| expect(type.name).to start_with('PuppetSpec::Bindings::') }
    end

    it 'all types extend from PuppetSpec::Bindings::BindingsModelObject' do
      type_set.types.values.each do |type|
        expect(find_parent(type, 'PuppetSpec::Bindings::BindingsModelObject').name).to eq('PuppetSpec::Bindings::BindingsModelObject')
      end
    end
  end

  context 'AST model types' do
    let!(:impl_repo) { Loaders.implementation_registry }
    let!(:loader) {  Loaders.find_loader(nil) }
    let!(:type_set) { Types::TypeParser.singleton.parse('Puppet::AST', loader) }
    let!(:ast_classes) do
      Model.constants.each_with_object([]) do |n, a|
        cls = Model.const_get(n)
        a << cls if cls.is_a?(Class) && cls.respond_to?(:ecore)
      end
    end

    it 'can be mapped from the ecore classes found in Puppet::Pops::Model' do
      ast_classes.each { |ast_class| expect(impl_repo.type_for_module(ast_class)).to be_a(Types::PObjectType) }
    end

    it 'are contained in a TypeSet named Puppet::AST' do
      expect(type_set).to be_a(Types::PTypeSetType)
      expect(type_set.name).to eq('Puppet::AST')
      expect(type_set.types.size).to eql(ast_classes.size + 1)  # +1 because the Locator is added
    end

    it 'all reside in the Puppet::AST namespace' do
      type_set.types.values.each {|type| expect(type.name).to start_with('Puppet::AST::') }
    end

    it 'all extend from Puppet::AST::PopsObject' do
      type_set.types.values.each do |type|
        next if type.name == 'Puppet::AST::Locator'
        expect(find_parent(type, 'Puppet::AST::PopsObject').name).to eq('Puppet::AST::PopsObject')
      end
    end
  end
end
end
end
