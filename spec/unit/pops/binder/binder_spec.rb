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

  # TODO: Test binder + parent binder
  context 'when defining layers' do

#    it 'redefinition is not allowed' do
#      expect do
#        b = binder()
#        b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
#        b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
#      end.to raise_error(/Cannot redefine its content/)
#    end
#
#    it 'a binder should report being configured when layers have been defined' do
#      b = binder()
#      b.configured?().should == false
#      b.define_layers(factory.layered_bindings(test_layer_with_empty_bindings))
#      b.configured?().should == true
#    end
  end
end