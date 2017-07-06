require 'spec_helper'
require 'puppet/pops'

module InjectorSpecModule
  def injector(binder)
    Puppet::Pops::Binder::Injector.new(binder)
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

  # Returns a binder
  #
  def configured_binder
    b = Puppet::Pops::Binder::Binder.new()
    b
  end

  class TestDuck
  end

  class Daffy < TestDuck
  end


  class AngryDuck < TestDuck
    # Supports assisted inject, returning a Donald duck as the default impl of Duck
    def self.inject(injector, scope, binding, *args)
      Donald.new()
    end
  end

  class Donald < AngryDuck
  end

  class ArneAnka < AngryDuck
    attr_reader :label

    def initialize()
      @label = 'A Swedish angry cartoon duck'
    end
  end

  class ScroogeMcDuck < TestDuck
    attr_reader :fortune

    # Supports assisted inject, returning an ScroogeMcDuck with 1$ fortune or first arg in args
    # Note that when injected (via instance producer, or implict assisted inject, the inject method
    # always wins.
    def self.inject(injector, scope, binding, *args)
      self.new(args[0].nil? ? 1 : args[0])
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
  class ScroogeProducer < Puppet::Pops::Binder::Producers::Producer
    attr_reader :next_capital
    def initialize
      @next_capital = 100
    end
    def produce(scope)
      ScroogeMcDuck.new(@next_capital *= 2)
    end
  end
end

describe 'Injector' do
  include InjectorSpecModule

  let(:bindings)  { factory.named_bindings('test') }
  let(:scope)     { null_scope()}
  let(:binder)    { Puppet::Pops::Binder::Binder }

  let(:lbinder)   do
    binder.new(layered_bindings)
  end

  def duck_type
    # create distinct instances
    type_factory.ruby(InjectorSpecModule::TestDuck)
  end

  let(:layered_bindings) { factory.layered_bindings(test_layer_with_bindings(bindings.model)) }

  context 'When created' do
    it 'should not raise an error if binder is configured' do
      expect { injector(lbinder) }.to_not raise_error
    end

    it 'should create an empty injector given an empty binder' do
      expect { binder.new(layered_bindings) }.to_not raise_exception
    end

    it "should be possible to reference the TypeCalculator" do
      expect(injector(lbinder).type_calculator.is_a?(Puppet::Pops::Types::TypeCalculator)).to eq(true)
    end

    it "should be possible to reference the KeyFactory" do
      expect(injector(lbinder).key_factory.is_a?(Puppet::Pops::Binder::KeyFactory)).to eq(true)
    end

    it "can be created using a model" do
      bindings.bind.name('a_string').to('42')
      injector = Puppet::Pops::Binder::Injector.create_from_model(layered_bindings)
      expect(injector.lookup(scope, 'a_string')).to eq('42')
    end

    it 'can be created using a block' do
      injector = Puppet::Pops::Binder::Injector.create('test') do
        bind.name('a_string').to('42')
      end
      expect(injector.lookup(scope, 'a_string')).to eq('42')
    end

    it 'can be created using a hash' do
      injector = Puppet::Pops::Binder::Injector.create_from_hash('test', 'a_string' => '42')
      expect(injector.lookup(scope, 'a_string')).to eq('42')
    end

    it 'can be created using an overriding injector with block' do
      injector = Puppet::Pops::Binder::Injector.create('test') do
        bind.name('a_string').to('42')
      end
      injector2 = injector.override('override') do
        bind.name('a_string').to('43')
      end
      expect(injector.lookup(scope, 'a_string')).to eq('42')
      expect(injector2.lookup(scope, 'a_string')).to eq('43')
    end

    it 'can be created using an overriding injector with hash' do
      injector = Puppet::Pops::Binder::Injector.create_from_hash('test', 'a_string' => '42')
      injector2 = injector.override_with_hash('override', 'a_string' => '43')
      expect(injector.lookup(scope, 'a_string')).to eq('42')
      expect(injector2.lookup(scope, 'a_string')).to eq('43')
    end

    it "can be created using an overriding injector with a model" do
      injector = Puppet::Pops::Binder::Injector.create_from_hash('test', 'a_string' => '42')
      bindings.bind.name('a_string').to('43')
      injector2 = injector.override_with_model(layered_bindings)
      expect(injector.lookup(scope, 'a_string')).to eq('42')
      expect(injector2.lookup(scope, 'a_string')).to eq('43')
    end
  end

  context "When looking up objects" do
    it 'lookup(scope, name) finds bound object of type Data with given name' do
      bindings.bind().name('a_string').to('42')
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq('42')
    end

    context 'a block transforming the result can be given' do
      it 'that transform a found value given scope and value' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup(scope, 'a_string') {|zcope, val| val + '42' }).to eq('4242')
      end

      it 'that transform a found value given only value' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup(scope, 'a_string') {|val| val + '42' }).to eq('4242')
      end

      it 'that produces a default value when entry is missing' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup(scope, 'a_non_existing_string') {|val| val ? (raise Error, "Should not happen") : '4242' }).to eq('4242')
      end
    end

    context "and class is not bound" do
      it "assisted inject kicks in for classes with zero args constructor" do
        duck_type = type_factory.ruby(InjectorSpecModule::Daffy)
        injector = injector(lbinder)
        expect(injector.lookup(scope, duck_type).is_a?(InjectorSpecModule::Daffy)).to eq(true)
        expect(injector.lookup_producer(scope, duck_type).produce(scope).is_a?(InjectorSpecModule::Daffy)).to eq(true)
      end

      it "assisted inject produces same instance on lookup but not on lookup producer" do
        duck_type = type_factory.ruby(InjectorSpecModule::Daffy)
        injector = injector(lbinder)
        d1 = injector.lookup(scope, duck_type)
        d2 = injector.lookup(scope, duck_type)
        expect(d1.equal?(d2)).to eq(true)

        d1 = injector.lookup_producer(scope, duck_type).produce(scope)
        d2 = injector.lookup_producer(scope, duck_type).produce(scope)
        expect(d1.equal?(d2)).to eq(false)
      end

      it "assisted inject kicks in for classes with a class inject method" do
        duck_type = type_factory.ruby(InjectorSpecModule::ScroogeMcDuck)
        injector = injector(lbinder)
        # Do not pass any arguments, the ScroogeMcDuck :inject method should pick 1 by default
        # This tests zero args passed
        expect(injector.lookup(scope, duck_type).fortune).to eq(1)
        expect(injector.lookup_producer(scope, duck_type).produce(scope).fortune).to eq(1)
      end

      it "assisted inject selects the inject method if it exists over a zero args constructor" do
        injector = injector(lbinder)
        duck_type = type_factory.ruby(InjectorSpecModule::AngryDuck)
        expect(injector.lookup(scope, duck_type).is_a?(InjectorSpecModule::Donald)).to eq(true)
        expect(injector.lookup_producer(scope, duck_type).produce(scope).is_a?(InjectorSpecModule::Donald)).to eq(true)
      end

      it "assisted inject selects the zero args constructor if injector is from a superclass" do
        injector = injector(lbinder)
        duck_type = type_factory.ruby(InjectorSpecModule::ArneAnka)
        expect(injector.lookup(scope, duck_type).is_a?(InjectorSpecModule::ArneAnka)).to eq(true)
        expect(injector.lookup_producer(scope, duck_type).produce(scope).is_a?(InjectorSpecModule::ArneAnka)).to eq(true)
      end
    end

    context "and multiple layers are in use" do
      it "a higher layer shadows anything in a lower layer" do
        bindings1 = factory.named_bindings('test1')
        bindings1.bind().name('a_string').to('bad stuff')
        lower_layer =  factory.named_layer('lower-layer', bindings1.model)

        bindings2 = factory.named_bindings('test2')
        bindings2.bind().name('a_string').to('good stuff')
        higher_layer =  factory.named_layer('higher-layer', bindings2.model)

        injector = injector(binder.new(factory.layered_bindings(higher_layer, lower_layer)))
        expect(injector.lookup(scope,'a_string')).to eq('good stuff')
      end

      it "a higher layer may not shadow a lower layer binding that is final" do
        bindings1 = factory.named_bindings('test1')
        bindings1.bind().final.name('a_string').to('required stuff')
        lower_layer =  factory.named_layer('lower-layer', bindings1.model)

        bindings2 = factory.named_bindings('test2')
        bindings2.bind().name('a_string').to('contraband')
        higher_layer =  factory.named_layer('higher-layer', bindings2.model)
        expect {
         injector = injector(binder.new(factory.layered_bindings(higher_layer, lower_layer)))
        }.to raise_error(/Override of final binding not allowed/)
      end
    end

    context "and dealing with Data types" do
      let(:lbinder) { binder.new(layered_bindings) }

      it "should treat all data as same type w.r.t. key" do
        bindings.bind().name('a_string').to('42')
        bindings.bind().name('an_int').to(43)
        bindings.bind().name('a_float').to(3.14)
        bindings.bind().name('a_boolean').to(true)
        bindings.bind().name('an_array').to([1,2,3])
        bindings.bind().name('a_hash').to({'a'=>1,'b'=>2,'c'=>3})

        injector = injector(lbinder)
        expect(injector.lookup(scope,'a_string')).to  eq('42')
        expect(injector.lookup(scope,'an_int')).to    eq(43)
        expect(injector.lookup(scope,'a_float')).to   eq(3.14)
        expect(injector.lookup(scope,'a_boolean')).to eq(true)
        expect(injector.lookup(scope,'an_array')).to  eq([1,2,3])
        expect(injector.lookup(scope,'a_hash')).to    eq({'a'=>1,'b'=>2,'c'=>3})
      end

      it "should provide type-safe lookup of given type/name" do
        bindings.bind().string().name('a_string').to('42')
        bindings.bind().integer().name('an_int').to(43)
        bindings.bind().float().name('a_float').to(3.14)
        bindings.bind().boolean().name('a_boolean').to(true)
        bindings.bind().array_of_data().name('an_array').to([1,2,3])
        bindings.bind().hash_of_data().name('a_hash').to({'a'=>1,'b'=>2,'c'=>3})

        injector = injector(lbinder)

        # Check lookup using implied Data type
        expect(injector.lookup(scope,'a_string')).to  eq('42')
        expect(injector.lookup(scope,'an_int')).to    eq(43)
        expect(injector.lookup(scope,'a_float')).to   eq(3.14)
        expect(injector.lookup(scope,'a_boolean')).to eq(true)
        expect(injector.lookup(scope,'an_array')).to  eq([1,2,3])
        expect(injector.lookup(scope,'a_hash')).to    eq({'a'=>1,'b'=>2,'c'=>3})

        # Check lookup using expected type
        expect(injector.lookup(scope,type_factory.string(), 'a_string')).to        eq('42')
        expect(injector.lookup(scope,type_factory.integer(), 'an_int')).to         eq(43)
        expect(injector.lookup(scope,type_factory.float(),'a_float')).to           eq(3.14)
        expect(injector.lookup(scope,type_factory.boolean(),'a_boolean')).to       eq(true)
        expect(injector.lookup(scope,type_factory.array_of_data(),'an_array')).to  eq([1,2,3])
        expect(injector.lookup(scope,type_factory.hash_of_data(),'a_hash')).to     eq({'a'=>1,'b'=>2,'c'=>3})

        # Check lookup using wrong type
        expect { injector.lookup(scope,type_factory.integer(), 'a_string')}.to raise_error(/Type error/)
        expect { injector.lookup(scope,type_factory.string(), 'an_int')}.to raise_error(/Type error/)
        expect { injector.lookup(scope,type_factory.string(),'a_float')}.to raise_error(/Type error/)
        expect { injector.lookup(scope,type_factory.string(),'a_boolean')}.to raise_error(/Type error/)
        expect { injector.lookup(scope,type_factory.string(),'an_array')}.to raise_error(/Type error/)
        expect { injector.lookup(scope,type_factory.string(),'a_hash')}.to raise_error(/Type error/)
      end
    end
  end

  context "When looking up producer" do
    it 'the value is produced by calling produce(scope)' do
      bindings.bind().name('a_string').to('42')
      expect(injector(lbinder).lookup_producer(scope, 'a_string').produce(scope)).to eq('42')
    end

    context 'a block transforming the result can be given' do
      it 'that transform a found value given scope and producer' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup_producer(scope, 'a_string') {|zcope, p| p.produce(zcope) + '42' }).to eq('4242')
      end

      it 'that transform a found value given only producer' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup_producer(scope, 'a_string') {|p| p.produce(scope) + '42' }).to eq('4242')
      end

      it 'that can produce a default value when entry is not found' do
        bindings.bind().name('a_string').to('42')
        expect(injector(lbinder).lookup_producer(scope, 'a_non_existing_string') {|p| p ? (raise Error,"Should not happen") : '4242' }).to eq('4242')
      end
    end
  end

  context "When dealing with singleton vs. non singleton" do
    it "should produce the same instance when producer is a singleton" do
      bindings.bind().name('a_string').to('42')
      injector = injector(lbinder)
      a = injector.lookup(scope, 'a_string')
      b = injector.lookup(scope, 'a_string')
      expect(a.equal?(b)).to eq(true)
    end

    it "should produce different instances when producer is a non singleton producer" do
      bindings.bind().name('a_string').to_series_of('42')
      injector = injector(lbinder)
      a = injector.lookup(scope, 'a_string')
      b = injector.lookup(scope, 'a_string')
      expect(a).to eq('42')
      expect(b).to eq('42')
      expect(a.equal?(b)).to eq(false)
    end
  end

  context "When using the lookup producer" do
    it "should lookup again to produce a value" do
      bindings.bind().name('a_string').to_lookup_of('another_string')
      bindings.bind().name('another_string').to('hello')
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq('hello')
    end

    it "should produce nil if looked up key does not exist" do
      bindings.bind().name('a_string').to_lookup_of('non_existing')
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq(nil)
    end

    it "should report an error if lookup loop is detected" do
      bindings.bind().name('a_string').to_lookup_of('a_string')
      expect { injector(lbinder).lookup(scope, 'a_string') }.to raise_error(/Lookup loop/)
    end
  end

  context "When using the hash lookup producer" do
    it "should lookup a key in looked up hash" do
      data_hash = type_factory.hash_of_data()
      bindings.bind().name('a_string').to_hash_lookup_of(data_hash, 'a_hash', 'huey')
      bindings.bind().name('a_hash').to({'huey' => 'red', 'dewey' => 'blue', 'louie' => 'green'})
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq('red')
    end

    it "should produce nil if looked up entry does not exist" do
      data_hash = type_factory.hash_of_data()
      bindings.bind().name('a_string').to_hash_lookup_of(data_hash, 'non_existing_entry', 'huey')
      bindings.bind().name('a_hash').to({'huey' => 'red', 'dewey' => 'blue', 'louie' => 'green'})
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq(nil)
    end
  end

  context "When using the first found producer" do
    it "should lookup until it finds a value, but not further" do
      bindings.bind().name('a_string').to_first_found('b_string', 'c_string', 'g_string')
      bindings.bind().name('c_string').to('hello')
      bindings.bind().name('g_string').to('Oh, mrs. Smith...')
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq('hello')
    end

    it "should lookup until it finds a value using mix of type and name, but not further" do
      bindings.bind().name('a_string').to_first_found('b_string', [type_factory.string, 'c_string'], 'g_string')
      bindings.bind().name('c_string').to('hello')
      bindings.bind().name('g_string').to('Oh, mrs. Smith...')
      expect(injector(lbinder).lookup(scope, 'a_string')).to eq('hello')
    end
  end

  context "When producing instances" do
    it "should lookup an instance of a class without arguments" do
      bindings.bind().type(duck_type).name('the_duck').to(InjectorSpecModule::Daffy)
      expect(injector(lbinder).lookup(scope, duck_type, 'the_duck').is_a?(InjectorSpecModule::Daffy)).to eq(true)
    end

    it "should lookup an instance of a class with arguments" do
      bindings.bind().type(duck_type).name('the_duck').to(InjectorSpecModule::ScroogeMcDuck, 1234)
      injector = injector(lbinder)

      the_duck = injector.lookup(scope, duck_type, 'the_duck')
      expect(the_duck.is_a?(InjectorSpecModule::ScroogeMcDuck)).to eq(true)
      expect(the_duck.fortune).to eq(1234)
    end

    it "singleton producer should not be recreated between lookups" do
      bindings.bind().type(duck_type).name('the_duck').to_producer(InjectorSpecModule::ScroogeProducer)
      injector = injector(lbinder)

      the_duck = injector.lookup(scope, duck_type, 'the_duck')
      expect(the_duck.is_a?(InjectorSpecModule::ScroogeMcDuck)).to eq(true)
      expect(the_duck.fortune).to eq(200)

      # singleton, do it again to get next value in series - it is the producer that is a singleton
      # not the produced value
      the_duck = injector.lookup(scope, duck_type, 'the_duck')
      expect(the_duck.is_a?(InjectorSpecModule::ScroogeMcDuck)).to eq(true)
      expect(the_duck.fortune).to eq(400)

      duck_producer = injector.lookup_producer(scope, duck_type, 'the_duck')
      expect(duck_producer.produce(scope).fortune).to eq(800)
    end

    it "series of producers should recreate producer on each lookup and lookup_producer" do
      bindings.bind().type(duck_type).name('the_duck').to_producer_series(InjectorSpecModule::ScroogeProducer)
      injector = injector(lbinder)

      duck_producer = injector.lookup_producer(scope, duck_type, 'the_duck')
      expect(duck_producer.produce(scope).fortune()).to eq(200)
      expect(duck_producer.produce(scope).fortune()).to eq(400)

      # series, each lookup gets a new producer (initialized to produce 200)
      duck_producer = injector.lookup_producer(scope, duck_type, 'the_duck')
      expect(duck_producer.produce(scope).fortune()).to eq(200)
      expect(duck_producer.produce(scope).fortune()).to eq(400)

      expect(injector.lookup(scope, duck_type, 'the_duck').fortune()).to eq(200)
      expect(injector.lookup(scope, duck_type, 'the_duck').fortune()).to eq(200)
    end
  end

  context "When working with multibind" do
    context "of hash kind" do
      it "a multibind produces contributed items keyed by their bound key-name" do
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('nephew1').to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('nephew2').to(InjectorSpecModule::NamedDuck, 'Dewey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('nephew3').to(InjectorSpecModule::NamedDuck, 'Louie')

        injector = injector(lbinder)
        the_ducks = injector.lookup(scope, hash_of_duck, "donalds_nephews")
        expect(the_ducks.size).to eq(3)
        expect(the_ducks['nephew1'].name).to eq('Huey')
        expect(the_ducks['nephew2'].name).to eq('Dewey')
        expect(the_ducks['nephew3'].name).to eq('Louie')
      end

      it "is an error to not bind contribution with a name" do
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        # missing name
        bindings.bind.in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Dewey')

        expect {
          the_ducks = injector(lbinder).lookup(scope, hash_of_duck, "donalds_nephews")
        }.to raise_error(/must have a name/)
      end

      it "is an error to bind with duplicate key when using default (priority) conflict resolution" do
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews')
        # missing name
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Dewey')

        expect {
          the_ducks = injector(lbinder).lookup(scope, hash_of_duck, "donalds_nephews")
        }.to raise_error(/Duplicate key/)
      end

      it "is not an error to bind with duplicate key when using (ignore) conflict resolution" do
        hash_of_duck = type_factory.hash_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(hash_of_duck).name('donalds_nephews').producer_options(:conflict_resolution => :ignore)
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Huey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('foo').to(InjectorSpecModule::NamedDuck, 'Dewey')

        expect {
          the_ducks = injector(lbinder).lookup(scope, hash_of_duck, "donalds_nephews")
        }.to_not raise_error
      end

      it "should produce detailed type error message" do
        hash_of_integer = type_factory.hash_of(type_factory.integer())

        multibind_id = "ints"
        mb = bindings.multibind(multibind_id).type(hash_of_integer).name('donalds_family')
        bindings.bind.in_multibind(multibind_id).name('nephew').to('Huey')

        expect { ducks = injector(lbinder).lookup(scope, 'donalds_family')
        }.to raise_error(%r{expected: Integer, got: String})
      end

      it "should be possible to combine hash multibind contributions with append on conflict" do
        # This case uses a multibind of individual strings, but combines them
        # into an array bound to a hash key
        # (There are other ways to do this - e.g. have the multibind lookup a multibind
        # of array type to which nephews are contributed).
        #
        hash_of_data = type_factory.hash_of_data()
        multibind_id = "ducks"
        mb = bindings.multibind(multibind_id).type(hash_of_data).name('donalds_family')
        mb.producer_options(:conflict_resolution => :append)

        bindings.bind.in_multibind(multibind_id).name('nephews').to('Huey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Dewey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Louie')
        bindings.bind.in_multibind(multibind_id).name('uncles').to('Scrooge McDuck')
        bindings.bind.in_multibind(multibind_id).name('uncles').to('Ludwig Von Drake')

        ducks = injector(lbinder).lookup(scope, 'donalds_family')

        expect(ducks['nephews']).to eq(['Huey', 'Dewey', 'Louie'])
        expect(ducks['uncles']).to eq(['Scrooge McDuck', 'Ludwig Von Drake'])
      end

      it "should be possible to combine hash multibind contributions with append, flat, and uniq, on conflict" do
        # This case uses a multibind of individual strings, but combines them
        # into an array bound to a hash key
        # (There are other ways to do this - e.g. have the multibind lookup a multibind
        # of array type to which nephews are contributed).
        #
        hash_of_data = type_factory.hash_of_data()
        multibind_id = "ducks"
        mb = bindings.multibind(multibind_id).type(hash_of_data).name('donalds_family')
        mb.producer_options(:conflict_resolution => :append, :flatten => true, :uniq => true)

        bindings.bind.in_multibind(multibind_id).name('nephews').to('Huey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Huey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Dewey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to(['Huey', ['Louie'], 'Dewey'])
        bindings.bind.in_multibind(multibind_id).name('uncles').to('Scrooge McDuck')
        bindings.bind.in_multibind(multibind_id).name('uncles').to('Ludwig Von Drake')

        ducks = injector(lbinder).lookup(scope, 'donalds_family')

        expect(ducks['nephews']).to eq(['Huey', 'Dewey', 'Louie'])
        expect(ducks['uncles']).to eq(['Scrooge McDuck', 'Ludwig Von Drake'])
      end

      it "should fail attempts to append, perform  uniq or flatten on type incompatible multibind hash" do
        hash_of_integer = type_factory.hash_of(type_factory.integer())
        ids = ["ducks1", "ducks2", "ducks3"]
        mb = bindings.multibind(ids[0]).type(hash_of_integer).name('broken_family0')
        mb.producer_options(:conflict_resolution => :append)
        mb = bindings.multibind(ids[1]).type(hash_of_integer).name('broken_family1')
        mb.producer_options(:flatten => :true)
        mb = bindings.multibind(ids[2]).type(hash_of_integer).name('broken_family2')
        mb.producer_options(:uniq => :true)

        injector = injector(binder.new(factory.layered_bindings(test_layer_with_bindings(bindings.model))))
        expect { injector.lookup(scope, 'broken_family0')}.to raise_error(/:conflict_resolution => :append/)
        expect { injector.lookup(scope, 'broken_family1')}.to raise_error(/:flatten/)
        expect { injector.lookup(scope, 'broken_family2')}.to raise_error(/:uniq/)
      end

      it "a higher priority contribution wins when resolution is :merge" do
        # THIS TEST MAY DEPEND ON HASH ORDER SINCE PRIORITY BASED ON CATEGORY IS REMOVED
        hash_of_data = type_factory.hash_of_data()
        multibind_id = "hashed_ducks"

        bindings.multibind(multibind_id).type(hash_of_data).name('donalds_nephews').producer_options(:conflict_resolution => :merge)

        mb1 = bindings.bind.in_multibind(multibind_id)
        mb1.name('nephew').to({'name' => 'Huey', 'is' => 'winner'})

        mb2 = bindings.bind.in_multibind(multibind_id)
        mb2.name('nephew').to({'name' => 'Dewey', 'is' => 'looser', 'has' => 'cap'})

        the_ducks = injector(binder.new(layered_bindings)).lookup(scope, "donalds_nephews");
        expect(the_ducks['nephew']['name']).to eq('Huey')
        expect(the_ducks['nephew']['is']).to eq('winner')
        expect(the_ducks['nephew']['has']).to eq('cap')
      end
    end

    context "of array kind" do
      it "an array multibind produces contributed items, names are allowed but ignored" do
        array_of_duck = type_factory.array_of(duck_type)
        multibind_id = "ducks"

        bindings.multibind(multibind_id).type(array_of_duck).name('donalds_nephews')
        # one with name (ignored, expect no error)
        bindings.bind.in_multibind(multibind_id).type(duck_type).name('nephew1').to(InjectorSpecModule::NamedDuck, 'Huey')
        # two without name
        bindings.bind.in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Dewey')
        bindings.bind.in_multibind(multibind_id).type(duck_type).to(InjectorSpecModule::NamedDuck, 'Louie')

        the_ducks = injector(lbinder).lookup(scope, array_of_duck, "donalds_nephews")
        expect(the_ducks.size).to eq(3)
        expect(the_ducks.collect {|d| d.name }.sort).to eq(['Dewey', 'Huey', 'Louie'])
      end

      it "should be able to make result contain only unique entries" do
        # This case uses a multibind of individual strings, and combines them
        # into an array of unique values
        #
        array_of_data = type_factory.array_of_data()
        multibind_id = "ducks"
        mb = bindings.multibind(multibind_id).type(array_of_data).name('donalds_family')
        # turn off priority on named to not trigger conflict as all additions have the same precedence
        # (could have used the default for unnamed and add unnamed entries).
        mb.producer_options(:priority_on_named => false, :uniq => true)

        bindings.bind.in_multibind(multibind_id).name('nephews').to('Huey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Dewey')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Dewey') # duplicate
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Louie')
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Louie') # duplicate
        bindings.bind.in_multibind(multibind_id).name('nephews').to('Louie') # duplicate

        ducks = injector(lbinder).lookup(scope, 'donalds_family')
        expect(ducks).to eq(['Huey', 'Dewey', 'Louie'])
      end

      it "should be able to contribute elements and arrays of elements and flatten 1 level" do
        # This case uses a multibind of individual strings and arrays, and combines them
        # into an array of flattened
        #
        array_of_string = type_factory.array_of(type_factory.string())

        multibind_id = "ducks"
        mb = bindings.multibind(multibind_id).type(array_of_string).name('donalds_family')
        # flatten one level
        mb.producer_options(:flatten => 1)

        bindings.bind.in_multibind(multibind_id).to('Huey')
        bindings.bind.in_multibind(multibind_id).to('Dewey')
        bindings.bind.in_multibind(multibind_id).to('Louie') # duplicate
        bindings.bind.in_multibind(multibind_id).to(['Huey', 'Dewey', 'Louie'])

        ducks = injector(lbinder).lookup(scope, 'donalds_family')
        expect(ducks).to eq(['Huey', 'Dewey', 'Louie', 'Huey', 'Dewey', 'Louie'])
      end

      it "should produce detailed type error message" do
        array_of_integer = type_factory.array_of(type_factory.integer())

        multibind_id = "ints"
        mb = bindings.multibind(multibind_id).type(array_of_integer).name('donalds_family')
        bindings.bind.in_multibind(multibind_id).to('Huey')

        expect { ducks = injector(lbinder).lookup(scope, 'donalds_family')
        }.to raise_error(%r{expected: Integer, or Array\[Integer\], got: String})
      end
    end

    context "When using multibind in multibind" do
      it "a hash multibind can be contributed to another" do
        hash_of_data = type_factory.hash_of_data()
        mb1_id = 'data1'
        mb2_id = 'data2'
        top = bindings.multibind(mb1_id).type(hash_of_data).name("top")
        detail = bindings.multibind(mb2_id).type(hash_of_data).name("detail").in_multibind(mb1_id)

        bindings.bind.in_multibind(mb1_id).name('a').to(10)
        bindings.bind.in_multibind(mb1_id).name('b').to(20)
        bindings.bind.in_multibind(mb2_id).name('a').to(30)
        bindings.bind.in_multibind(mb2_id).name('b').to(40)
        expect( injector(lbinder).lookup(scope, "top") ).to eql({'detail' => {'a' => 30, 'b' => 40}, 'a' => 10, 'b' => 20})
      end
    end

    context "When looking up entries requiring evaluation" do
      let(:node)     { Puppet::Node.new('localhost') }
      let(:compiler) { Puppet::Parser::Compiler.new(node)}
      let(:scope)    { Puppet::Parser::Scope.new(compiler) }
      let(:parser)   { Puppet::Pops::Parser::Parser.new() }

      it "should be possible to lookup a concatenated string" do
        scope['duck'] = 'Donald Fauntleroy Duck'
        expr = parser.parse_string('"Hello $duck"').current()
        bindings.bind.name('the_duck').to(expr)
        expect(injector(lbinder).lookup(scope, 'the_duck')).to eq('Hello Donald Fauntleroy Duck')
      end

      it "should be possible to post process lookup with a puppet lambda" do
        model = parser.parse_string('fake() |$value| {$value + 1 }').current
        bindings.bind.name('an_int').to(42).producer_options( :transformer => model.body.lambda)
        expect(injector(lbinder).lookup(scope, 'an_int')).to eq(43)
      end

      it "should be possible to post process lookup with a ruby proc" do
        transformer = lambda {|value| value + 1 }
        bindings.bind.name('an_int').to(42).producer_options( :transformer => transformer)
        expect(injector(lbinder).lookup(scope, 'an_int')).to eq(43)
      end
    end
  end

  context "When there are problems with configuration" do
    let(:lbinder) { binder.new(layered_bindings) }

    it "reports error for surfacing abstract bindings" do
      bindings.bind.abstract.name('an_int')
      expect{injector(lbinder).lookup(scope, 'an_int') }.to raise_error(/The abstract binding .* was not overridden/)
    end

    it "does not report error for abstract binding that is ovrridden" do
      bindings.bind.abstract.name('an_int')
      bindings.bind.override.name('an_int').to(142)
      expect{ injector(lbinder).lookup(scope, 'an_int') }.to_not raise_error
    end

    it "reports error for overriding binding that does not override" do
      bindings.bind.override.name('an_int').to(42)
      expect{injector(lbinder).lookup(scope, 'an_int') }.to raise_error(/Binding with unresolved 'override' detected/)
    end

    it "reports error for binding  without producer" do
      bindings.bind.name('an_int')
      expect{injector(lbinder).lookup(scope, 'an_int') }.to raise_error(/Binding without producer/)
    end
  end
end
