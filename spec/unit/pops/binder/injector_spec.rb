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

  def type_calculator
    Puppet::Pops::Types::TypeCalculator
  end

  def type_factory
    Puppet::Pops::Types::TypeFactory
  end

  # Returns a binder with the effective categories highest/test, node/kermit, environment/dev (and implicit 'common')
  #
  def binder_with_categories
    b = binder()
    b.define_categories(factory.categories(['highest', 'test', 'node', 'kermit', 'environment','dev']))
    b
  end
end

describe 'Injector' do
  include InjectorSpecModule

  context 'When created' do
    it 'should raise an error when given binder is not configured at all' do
      expect { injector(binder()) }.to raise_error(/Given Binder is not configured/)
    end

    it 'should raise an error if binder has categories, but is not completely configured' do
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

    it 'should create an empty injector given an empty binder' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      binder.define_categories(factory.categories([]))
      expect { binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model))) }.to_not raise_exception
    end
  end

  context "When looking up" do
    it 'should perform a simple lookup in the common layer' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == '42'
    end

    context 'and conditionals are in use' do
      it "should be possible to shadow a bound value in a higher precedented category" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().name('a_string').to('42')
        bindings.when_in_category('environment', 'dev').bind().name('a_string').to('43')
        bindings.when_in_category('node', 'kermit').bind().name('a_string').to('being green')
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should == 'being green'
      end

      it "shadowing should not happen when not in a category" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().name('a_string').to('42')
        bindings.when_in_category('environment', 'dev').bind().name('a_string').to('43')
        bindings.when_in_category('node', 'piggy').bind().name('a_string').to('being green')
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should == '43'
      end

      it "multiple predicates makes binding more specific" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().name('a_string').to('42')
        bindings.when_in_category('environment', 'dev').bind().name('a_string').to('43')
        bindings.when_in_category('node', 'kermit').bind().name('a_string').to('being green')
        bindings.when_in_categories({'node'=>'kermit', 'environment'=>'dev'}).bind().name('a_string').to('being dev green')
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should == 'being dev green'
      end

      it "multiple predicates makes binding more specific, but not more specific than higher precedence" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().name('a_string').to('42')
        bindings.when_in_category('environment', 'dev').bind().name('a_string').to('43')
        bindings.when_in_category('node', 'kermit').bind().name('a_string').to('being green')
        bindings.when_in_categories({'node'=>'kermit', 'environment'=>'dev'}).bind().name('a_string').to('being dev green')
        bindings.when_in_category('highest', 'test').bind().name('a_string').to('bazinga')
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should == 'bazinga'
      end
    end

    context "and multiple layers are in use" do
      it "a higher layer shadows anything in a lower layer" do
        binder = binder_with_categories()

        bindings1 = factory.named_bindings('test1')
        bindings1.when_in_category("highest", "test").bind().name('a_string').to('bad stuff')
        lower_layer =  factory.named_layer('lower-layer', bindings1.model)

        bindings2 = factory.named_bindings('test2')
        bindings2.bind().name('a_string').to('good stuff')
        higher_layer =  factory.named_layer('higher-layer', bindings2.model)

        binder.define_layers(factory.layered_bindings(higher_layer, lower_layer))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should == 'good stuff'
      end
    end

    context "and dealing with Data types" do
      it "should treat all data as same type w.r.t. key" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().name('a_string').to('42')
        bindings.bind().name('an_int').to(43)
        bindings.bind().name('a_float').to(3.14)
        bindings.bind().name('a_boolean').to(true)
        bindings.bind().name('an_array').to([1,2,3])
        bindings.bind().name('a_hash').to({'a'=>1,'b'=>2,'c'=>3})

        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        injector.lookup(null_scope(),'a_string').should  == '42'
        injector.lookup(null_scope(),'an_int').should    == 43
        injector.lookup(null_scope(),'a_float').should   == 3.14
        injector.lookup(null_scope(),'a_boolean').should == true
        injector.lookup(null_scope(),'an_array').should  == [1,2,3]
        injector.lookup(null_scope(),'a_hash').should    == {'a'=>1,'b'=>2,'c'=>3}
      end

      it "should provide type-safe lookup of given type/name" do
        binder = binder_with_categories()
        bindings = factory.named_bindings('test')
        bindings.bind().string().name('a_string').to('42')
        bindings.bind().integer().name('an_int').to(43)
        bindings.bind().float().name('a_float').to(3.14)
        bindings.bind().boolean().name('a_boolean').to(true)
        bindings.bind().array_of_data().name('an_array').to([1,2,3])
        bindings.bind().hash_of_data().name('a_hash').to({'a'=>1,'b'=>2,'c'=>3})

        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)

        # Check lookup using implied Data type
        injector.lookup(null_scope(),'a_string').should  == '42'
        injector.lookup(null_scope(),'an_int').should    == 43
        injector.lookup(null_scope(),'a_float').should   == 3.14
        injector.lookup(null_scope(),'a_boolean').should == true
        injector.lookup(null_scope(),'an_array').should  == [1,2,3]
        injector.lookup(null_scope(),'a_hash').should    == {'a'=>1,'b'=>2,'c'=>3}

        # Check lookup using expected type
        injector.lookup(null_scope(),type_factory.string(), 'a_string').should        == '42'
        injector.lookup(null_scope(),type_factory.integer(), 'an_int').should         == 43
        injector.lookup(null_scope(),type_factory.float(),'a_float').should           == 3.14
        injector.lookup(null_scope(),type_factory.boolean(),'a_boolean').should       == true
        injector.lookup(null_scope(),type_factory.array_of_data(),'an_array').should  == [1,2,3]
        injector.lookup(null_scope(),type_factory.hash_of_data(),'a_hash').should     == {'a'=>1,'b'=>2,'c'=>3}

        # Check lookup using wrong type
        expect { injector.lookup(null_scope(),type_factory.integer(), 'a_string')}.to raise_error(/Type error/)
        expect { injector.lookup(null_scope(),type_factory.string(), 'an_int')}.to raise_error(/Type error/)
        expect { injector.lookup(null_scope(),type_factory.string(),'a_float')}.to raise_error(/Type error/)
        expect { injector.lookup(null_scope(),type_factory.string(),'a_boolean')}.to raise_error(/Type error/)
        expect { injector.lookup(null_scope(),type_factory.string(),'an_array')}.to raise_error(/Type error/)
        expect { injector.lookup(null_scope(),type_factory.string(),'a_hash')}.to raise_error(/Type error/)
      end
    end
  end
  context "When looking up producer" do
    it 'should perform a simple lookup in the common layer' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      producer = injector.lookup_producer(null_scope(), 'a_string')
      producer.produce(null_scope()).should == '42'
    end

  end
end