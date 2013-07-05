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


  class AngryDuck < TestDuck
    # Supports assisted inject, returning a Donald duck as the default impl of Duck
    def self.inject(injector, scope)
      Donald.new()
    end
  end

  class Donald < AngryDuck
  end

  class UncleMcScrooge < TestDuck
    attr_reader :fortune

    # Supports assisted inject, returning an UncleMcScrooge with 1$ fortune
    def self.inject(injector, scope)
      self.new(1)
    end

    def initialize(fortune)
      @fortune = fortune
    end
  end

  class NamedDuck < TestDuck
    attr_reader :name
    def initialize(name)
      @name = name
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

    context "and class is not bound" do
      it "assisted inject should kick in for classes with zero args constructor" do
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        duck_type = type_factory.ruby(InjectorSpecModule::Daffy)
        injector.lookup(null_scope(), duck_type).is_a?(InjectorSpecModule::Daffy).should == true
        injector.lookup_producer(null_scope(), duck_type).produce(null_scope()).is_a?(InjectorSpecModule::Daffy).should == true
      end

      it "assisted inject should kick in for classes with a class inject method" do
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        duck_type = type_factory.ruby(InjectorSpecModule::UncleMcScrooge)
        injector.lookup(null_scope(), duck_type).fortune.should == 1
        injector.lookup_producer(null_scope(), duck_type).produce(null_scope()).fortune.should == 1
      end

      it "assisted inject should select inject if it exists over zero args constructor" do
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        duck_type = type_factory.ruby(InjectorSpecModule::AngryDuck)
        injector.lookup(null_scope(), duck_type).is_a?(InjectorSpecModule::Donald).should == true
        injector.lookup_producer(null_scope(), duck_type).produce(null_scope()).is_a?(InjectorSpecModule::Donald).should == true
      end
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

  context "When dealing with singleton vs. non singleton" do
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

  context "When using the lookup producer" do
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

    it "should produce nil if looked up key does not exist" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to_lookup_of('non_existing')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == nil
    end

    it "should report an error if lookup loop is detected" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      bindings.bind().name('a_string').to_lookup_of('a_string')

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      expect { injector.lookup(null_scope(), 'a_string') }.to raise_error(/Lookup loop/)
    end
  end

  context "When using the hash lookup producer" do
    it "should lookup a key in looked up hash" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      data_hash = type_factory.hash_of_data()

      bindings.bind().name('a_string').to_hash_lookup_of(data_hash, 'a_hash', 'huey')
      bindings.bind().name('a_hash').to({'huey' => 'red', 'dewey' => 'blue', 'louie' => 'green'})

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == 'red'
    end

    it "should produce nil if looked up entry does not exist" do
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      data_hash = type_factory.hash_of_data()

      bindings.bind().name('a_string').to_hash_lookup_of(data_hash, 'non_existing_entry', 'huey')
      bindings.bind().name('a_hash').to({'huey' => 'red', 'dewey' => 'blue', 'louie' => 'green'})

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      injector.lookup(null_scope(), 'a_string').should == nil
    end
  end

  context "When using the first found producer" do
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

  context "When producing instances" do
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

    it "singleton producer should not be recreated between lookups" do
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

      duck_producer = injector.lookup_producer(null_scope(), duck_type, 'the_duck')
      duck_producer.produce(null_scope()).fortune.should == 800
    end

    it "series of producers should recreate producer on each lookup and lookup_producer" do
      scope = null_scope()
      binder = Puppet::Pops::Binder::Binder.new()
      bindings = factory.named_bindings('test')
      duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
      bindings.bind().type(duck_type).name('the_duck').to_producer_series(InjectorSpecModule::ScroogeProducer)

      binder.define_categories(factory.categories([]))
      binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
      injector = injector(binder)
      duck_producer = injector.lookup_producer(scope, duck_type, 'the_duck')
      duck_producer.produce(scope).fortune().should == 200
      duck_producer.produce(scope).fortune().should == 400

      # series, each lookup gets a new producer (initialized to produce 200)
      duck_producer = injector.lookup_producer(scope, duck_type, 'the_duck')
      duck_producer.produce(scope).fortune().should == 200
      duck_producer.produce(scope).fortune().should == 400

      injector.lookup(scope, duck_type, 'the_duck').fortune().should == 200
      injector.lookup(scope, duck_type, 'the_duck').fortune().should == 200
    end
  end

  context "When working with multibind" do
    context "of hash kind" do
      it "a multibind produces contributed items keyed by their bound key-name" do
        scope = null_scope()
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('nephew1').to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('nephew2').to(InjectorSpecModule::NamedDuck, 'Dewey')
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('nephew3').to(InjectorSpecModule::NamedDuck, 'Louie')

        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        the_ducks = injector.lookup(scope, hash_of_duck, "donalds_nephews")
        the_ducks.size.should == 3
        the_ducks['nephew1'].name.should == 'Huey'
        the_ducks['nephew2'].name.should == 'Dewey'
        the_ducks['nephew3'].name.should == 'Louie'
      end

      it "is an error to not bind contribution with a name" do
        scope = null_scope()
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        # missing name
        bindings.bind_in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind_in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Dewey')

        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        expect {
          the_ducks = injector.lookup(scope, hash_of_duck, "donalds_nephews")
        }.to raise_error(/must have a name/)
      end

      it "is an error to bind with duplicate key" do
        scope = null_scope()
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        # missing name
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Dewey')

        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        expect {
          the_ducks = injector.lookup(scope, hash_of_duck, "donalds_nephews")
        }.to raise_error(/Duplicate key/)
      end
      it "is not an error to bind duplicate key if there is a handler" do
        # TODO: test hash with handler
        # Test Handler is a lambda or an injected handler class
      end
    end

    context "of array kind" do
      it "an array multibind produces contributed items, names are allowed but ignored" do
        scope = null_scope()
        binder = Puppet::Pops::Binder::Binder.new()
        bindings = factory.named_bindings('test')
        duck_type = type_factory.ruby(InjectorSpecModule::TestDuck)
        array_of_duck = type_factory.array_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(array_of_duck).name('donalds_nephews')
        # one with name (ignored, expect no error)
        bindings.bind_in_multibind(multibind_id).type(duck_type).name('nephew1').to(InjectorSpecModule::NamedDuck, 'Huey')
        # two without name
        bindings.bind_in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Dewey')
        bindings.bind_in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Louie')

        binder.define_categories(factory.categories([]))
        binder.define_layers(factory.layered_bindings(test_layer_with_bindings(bindings.model)))
        injector = injector(binder)
        the_ducks = injector.lookup(scope, array_of_duck, "donalds_nephews")
        the_ducks.size.should == 3
        the_ducks.collect {|d| d.name }.sort.should == ['Dewey', 'Huey', 'Louie']
      end
      it "should be able to use a handler to process each addition" do
        # TODO Array with combinator handler - say add unique, or doing to upper on entries
        # Test Both lambda handler, and injected handler
      end
    end
  end
  # TODO: test EvaluatingProducerDescriptor
  # TODO: test combinators for array and hash
  # TODO: test assisted inject (lookup and lookup producer)
end