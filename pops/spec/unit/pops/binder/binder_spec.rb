require 'spec_helper'
require 'puppet/pops'

module BinderSpecModule
  def factory()
    Puppet::Pops::Binder::BindingsFactory
  end

  def injector(binder)
    Puppet::Pops::Binder::Injector.new(binder)
  end

  def binder()
    Puppet::Pops::Binder::Binder.new()
  end

  def test_layer_with_empty_bindings
    factory.named_layer('test-layer', factory.named_bindings('test').model)
  end
end

describe 'Binder' do
  include BinderSpecModule

  context 'when defining categories' do
    it 'redefinition is not allowed' do
      expect do
        b = binder()
        b.define_categories(factory.categories([]))
        b.define_categories(factory.categories([]))
      end.to raise_error(/Cannot redefine/)
    end
  end

  context 'when defining layers' do
    it 'they must be defined after categories' do
      expect do
        binder().define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
      end.to raise_error(/Categories must be defined first/)
    end

    it 'redefinition is not allowed' do
      expect do
        b = binder()
        b.define_categories(factory.categories([]))
        b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
        b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
      end.to raise_error(/Cannot redefine its content/)
    end
  end

  context 'when defining categories and layers' do
    it 'a binder should report being configured when both categories and layers have been defined' do
      b = binder()
      b.configured?().should == false
      b.define_categories(factory.categories([]))
      b.configured?().should == false
      b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
      b.configured?().should == true
    end
  end
end