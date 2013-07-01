require 'spec_helper'
require 'puppet/pops'

module InjectorSpecModule
  def injector(binder)
    Puppet::Pops::Binder::Injector.new(binder)
  end

  def binder()
    Puppet::Pops::Binder::Binder.new()
  end

  def factory
    Puppet::Pops::Binder::BindingsFactory
  end

  def test_layer_with_empty_bindings
    factory.named_layer('test-layer', factory.named_bindings('test').model)
  end

  def test_layer_with_bindings(*bindings)
    factory.named_layer('test-layer', *bindings)
  end

  def null_scope()
    nil
  end
end

describe 'Injector' do
  include InjectorSpecModule

  context 'When created' do
    it 'should raise an error when given binder is unconfigured' do
      expect { injector(binder()) }.to raise_error(/Given Binder is not configured/)
    end

    it 'should raise an error if binder is not configured' do
      binder = binder()
      binder.define_categories(factory.categories([]))
      expect { injector(binder) }.to raise_error(/Given Binder is not configured/)
    end

    it 'should not raise an error if binder is configured' do
      binder = binder()
      binder.define_categories(factory.categories([]))
      bindings = factory.named_bindings('test')
      binder.define_layers(test_layer_with_bindings(bindings.model))
      binder.configured?().should == true # of something is very wrong
      expect { injector(binder) }.to_not raise_error
    end
  end

  it 'should create an empty injector given an empty binder' do
    binder = Puppet::Pops::Binder::Binder.new()
    bindings = factory.named_bindings('test')
    binder.define_categories(factory.categories([]))
    binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
  end

  it 'should performs a simple lookup in the common layer' do
    binder = Puppet::Pops::Binder::Binder.new()
    bindings = factory.named_bindings('test')
    bindings.bind().name('a_string').to('42')

    binder.define_categories(factory.categories([]))
    binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
    injector = injector(binder)
    injector.lookup(null_scope(), 'a_string').should == '42'
  end
end