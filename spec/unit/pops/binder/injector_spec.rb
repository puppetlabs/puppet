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

  class TestDuck
  end
  class Daffy < TestDuck
  end
  class Donald < TestDuck
  end
  class UncleMcScrooge < TestDuck
    attr_reader :fortune
    def initialize(fortune)
      @fortune = fortune
    end
  end

  # Test custom producer that on each produce returns a duck that is twice as rich as its predecessor
  class ScroogeProducer < Puppet::Pops::Binder::Producer
    attr_reader :next_capital
    def initialize
      @next_capital = 100
    end
    def produce(scope)
      UncleMcScrooge.new(@next_capital *= 2)
    end
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

    it "should be possible to reference the TypeCalculator" do
      binder = binder()
      binder.define_categories(factory.categories([]))
      bindings = factory.named_bindings('test')
      binder.define_layers(test_layer_with_bindings(bindings.model))
      binder.configured?().should == true # of something is very wrong
      i = injector(binder)
      i.type_calculator.is_a?(Puppet::Pops::Types::TypeCalculator).should == true
    end

    it "should be possible to reference the KeyFactory" do
      binder = binder()
      binder.define_categories(factory.categories([]))
      bindings = factory.named_bindings('test')
      binder.define_layers(test_layer_with_bindings(bindings.model))
      binder.configured?().should == true # of something is very wrong
      i = injector(binder)
      i.key_factory.is_a?(Puppet::Pops::Binder::KeyFactory).should == true
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

    it 'should be possible to use a block to further detail the lookup' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string') {|val| val + '42' }.should == '4242'
    end

    it 'should be possible to use a block to produce a default if entry is missing' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_non_existing_string') {|val| val ? val : '4242' }.should == '4242'
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

    it 'should be possible to use a block to further detail the lookup' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup_producer(null_scope(), 'a_string') {|scope, p| p.produce(scope) + '42' }.should == '4242'
    end

    it 'should be possible to use a block to produce a default value if entry is missing' do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup_producer(null_scope(), 'a_non_existing_string') {|scope, p| p ? p.produce(scope) : '4242' }.should == '4242'
    end

  end
  context "when dealing with singleton vs. non singleton" do
    it "should produce the same instance when producer is a singleton" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      a = injector.lookup(null_scope(), 'a_string')
      b = injector.lookup(null_scope(), 'a_string')
      a.equal?(b).should == true
    end

    it "should produce different instances when producer is a non singleton producer" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to_series_of('42')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      a = injector.lookup(null_scope(), 'a_string')
      b = injector.lookup(null_scope(), 'a_string')
      a.equal?(b).should == false
    end
  end

  context "when using the lookup producer" do
    it "should lookup again to produce a value" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to_lookup_of('another_string')
      bindings.bind().name('another_string').to('hello')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == 'hello'
    end
  end

  context "when using the first found producer" do
    it "should lookup until it finds a value, but no further" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to_first_found(['b_string', 'c_string', 'g_string'])
      bindings.bind().name('c_string').to('hello')
      bindings.bind().name('g_string').to('Oh, mrs. Smith...')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == 'hello'
    end
  end

  context "when producing instances" do
    it "should lookup an instance of a class without arguments" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
      bindings.bind().type(duck_type).name('the_duck').to(InjectorSpecModule::Daffy)

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), duck_type, 'the_duck').is_a?(InjectorSpecModule::Daffy).should == true
    end

    it "should lookup an instance of a class with arguments" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
      bindings.bind().type(duck_type).name('the_duck').to(InjectorSpecModule::UncleMcScrooge, 1234)
      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      the_duck = injector.lookup(null_scope(), duck_type, 'the_duck')
      the_duck.is_a?(InjectorSpecModule::UncleMcScrooge).should == true
      the_duck.fortune.should == 1234
    end

    it "should lookup a producer and use what it produces (when producer is singleton)" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
      bindings.bind().type(duck_type).name('the_duck').to_producer(InjectorSpecModule::ScroogeProducer)

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      the_duck = injector.lookup(null_scope(), duck_type, 'the_duck')
      the_duck.is_a?(InjectorSpecModule::UncleMcScrooge).should == true
      the_duck.fortune.should == 200
      # singleton, do it again to get next value in series - it is the producer that is a singleton
      # not the produced value
      the_duck = injector.lookup(null_scope(), duck_type, 'the_duck')
      the_duck.is_a?(InjectorSpecModule::UncleMcScrooge).should == true
      the_duck.fortune.should == 400
    end

    it "should lookup a producer and use what it produces (when producer is a series of producers)" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
      bindings.bind().type(duck_type).name('the_duck').to_producer_series(InjectorSpecModule::ScroogeProducer)

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      the_duck = injector.lookup(null_scope(), duck_type, 'the_duck')
      the_duck.is_a?(InjectorSpecModule::UncleMcScrooge).should == true
      the_duck.fortune.should == 200
      # series, each lookup gets a new producer (initialized to produce 200)
      the_duck = injector.lookup(null_scope(), duck_type, 'the_duck')
      the_duck.is_a?(InjectorSpecModule::UncleMcScrooge).should == true
      the_duck.fortune.should == 200
    end
  end

  # TODO: test producer producer
  # TODO: test first found producer
  # TODO: test multibinding (array, hash)  
end