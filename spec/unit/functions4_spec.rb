require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/pops'
require 'puppet_spec/scope'

module FunctionAPISpecModule
  class TestDuck
  end

  class TestFunctionLoader < Puppet::Pops::Loader::StaticLoader
    def initialize
      @functions = {}
    end

    def add_function(name, function)
      typed_name = Puppet::Pops::Loader::Loader::TypedName.new(:function, name)
      entry = Puppet::Pops::Loader::Loader::NamedEntry.new(typed_name, function, __FILE__)
      @functions[typed_name] = entry
    end

    # override StaticLoader
    def load_constant(typed_name)
      @functions[typed_name]
    end
  end
end

describe 'the 4x function api' do
  include FunctionAPISpecModule
  include PuppetSpec::Pops
  include PuppetSpec::Scope

  let(:loader) { FunctionAPISpecModule::TestFunctionLoader.new }

  it 'allows a simple function to be created without dispatch declaration' do
    f = Puppet::Functions.create_function('min') do
      def min(x,y)
        x <= y ? x : y
      end
    end

    # the produced result is a Class inheriting from Function
    expect(f.class).to be(Class)
    expect(f.superclass).to be(Puppet::Functions::Function)
    # and this class had the given name (not a real Ruby class name)
    expect(f.name).to eql('min')
  end

  it 'refuses to create functions that are not based on the Function class' do
    expect do
      Puppet::Functions.create_function('testing', Object) {}
    end.to raise_error(ArgumentError, 'Functions must be based on Puppet::Pops::Functions::Function. Got Object')
  end

  it 'a function without arguments can be defined and called without dispatch declaration' do
    f = create_noargs_function_class()
    func = f.new(:closure_scope, :loader)
    expect(func.call({})).to eql(10)
  end

  it 'an error is raised when calling a no arguments function with arguments' do
    f = create_noargs_function_class()
    func = f.new(:closure_scope, :loader)
    expect{func.call({}, 'surprise')}.to raise_error(ArgumentError, "function 'test' called with mis-matched arguments
expected:
  test() - arg count {0}
actual:
  test(String) - arg count {1}")
  end

  it 'a simple function can be called' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_true
    expect(func.call({}, 10,20)).to eql(10)
  end

  it 'an error is raised if called with too few arguments' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_true
    signature = if RUBY_VERSION =~ /^1\.8/
      'Any{2}'
    else
      'Any x, Any y'
    end
    expect do
      func.call({}, 10)
    end.to raise_error(ArgumentError, "function 'min' called with mis-matched arguments
expected:
  min(#{signature}) - arg count {2}
actual:
  min(Integer) - arg count {1}")
  end

  it 'an error is raised if called with too many arguments' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_true
    signature = if RUBY_VERSION =~ /^1\.8/
      'Any{2}'
    else
      'Any x, Any y'
    end
    expect do
      func.call({}, 10, 10, 10)
    end.to raise_error(ArgumentError, Regexp.new(Regexp.escape(
"function 'min' called with mis-matched arguments
expected:
  min(#{signature}) - arg count {2}
actual:
  min(Integer, Integer, Integer) - arg count {3}")))
  end

  it 'an error is raised if simple function-name and method are not matched' do
    expect do
      f = create_badly_named_method_function_class()
    end.to raise_error(ArgumentError, /Function Creation Error, cannot create a default dispatcher for function 'mix', no method with this name found/)
  end

  it 'the implementation separates dispatchers for different functions' do
    # this tests that meta programming / construction puts class attributes in the correct class
    f1 = create_min_function_class()
    f2 = create_max_function_class()

    d1 = f1.dispatcher
    d2 = f2.dispatcher

    expect(d1).to_not eql(d2)
    expect(d1.dispatchers[0]).to_not eql(d2.dispatchers[0])
  end

  context 'when using regular dispatch' do
    it 'a function can be created using dispatch and called' do
      f = create_min_function_class_using_dispatch()
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 3,4)).to eql(3)
    end

    it 'an error is raised with reference to given parameter names when called with mis-matched arguments' do
      f = create_min_function_class_using_dispatch()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_true
      expect do
        func.call({}, 10, 10, 10)
      end.to raise_error(ArgumentError, Regexp.new(Regexp.escape(
"function 'min' called with mis-matched arguments
expected:
  min(Numeric a, Numeric b) - arg count {2}
actual:
  min(Integer, Integer, Integer) - arg count {3}")))
    end

    it 'an error includes optional indicators and count for last element' do
      f = create_function_with_optionals_and_varargs()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_true
      signature = if RUBY_VERSION =~ /^1\.8/
        'Any{2,}'
      else
        'Any x, Any y, Any a?, Any b?, Any c{0,}'
      end
      expect do
        func.call({}, 10)
      end.to raise_error(ArgumentError,
"function 'min' called with mis-matched arguments
expected:
  min(#{signature}) - arg count {2,}
actual:
  min(Integer) - arg count {1}")
    end

    it 'an error includes optional indicators and count for last element when defined via dispatch' do
      f = create_function_with_optionals_and_varargs_via_dispatch()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_true
      expect do
        func.call({}, 10)
      end.to raise_error(ArgumentError,
"function 'min' called with mis-matched arguments
expected:
  min(Numeric x, Numeric y, Numeric a?, Numeric b?, Numeric c{0,}) - arg count {2,}
actual:
  min(Integer) - arg count {1}")
    end

    it 'a function can be created using dispatch and called' do
      f = create_min_function_class_disptaching_to_two_methods()
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 3,4)).to eql(3)
      expect(func.call({}, 'Apple', 'Banana')).to eql('Apple')
    end

    it 'an error is raised with reference to multiple methods when called with mis-matched arguments' do
      f = create_min_function_class_disptaching_to_two_methods()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_true
      expect do
        func.call({}, 10, 10, 10)
      end.to raise_error(ArgumentError,
"function 'min' called with mis-matched arguments
expected one of:
  min(Numeric a, Numeric b) - arg count {2}
  min(String s1, String s2) - arg count {2}
actual:
  min(Integer, Integer, Integer) - arg count {3}")
    end

    context 'can use injection' do
      before :all do
        injector = Puppet::Pops::Binder::Injector.create('test') do
          bind.name('a_string').to('evoe')
          bind.name('an_int').to(42)
        end
        Puppet.push_context({:injector => injector}, "injector for testing function API")
      end

      after :all do
        Puppet.pop_context()
      end

      it 'attributes can be injected' do
        f1 = create_function_with_class_injection()
        f = f1.new(:closure_scope, :loader)
        expect(f.test_attr2()).to eql("evoe")
        expect(f.serial().produce(nil)).to eql(42)
        expect(f.test_attr().class.name).to eql("FunctionAPISpecModule::TestDuck")
      end

      it 'parameters can be injected and woven with regular dispatch' do
        f1 = create_function_with_param_injection_regular()
        f = f1.new(:closure_scope, :loader)
        expect(f.call(nil, 10, 20)).to eql("evoe! 10, and 20 < 42 = true")
        expect(f.call(nil, 50, 20)).to eql("evoe! 50, and 20 < 42 = false")
      end
    end

    context 'when requesting a type' do
      it 'responds with a Callable for a single signature' do
        tf = Puppet::Pops::Types::TypeFactory
        fc = create_min_function_class_using_dispatch()
        t = fc.dispatcher.to_type
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.types).to eql([tf.numeric(), tf.numeric()])
        expect(t.block_type).to be_nil
      end

      it 'responds with a Variant[Callable...] for multiple signatures' do
        tf = Puppet::Pops::Types::TypeFactory
        fc = create_min_function_class_disptaching_to_two_methods()
        t = fc.dispatcher.to_type
        expect(t.class).to be(Puppet::Pops::Types::PVariantType)
        expect(t.types.size).to eql(2)
        t1 = t.types[0]
        expect(t1.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t1.param_types.types).to eql([tf.numeric(), tf.numeric()])
        expect(t1.block_type).to be_nil
        t2 = t.types[1]
        expect(t2.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t2.param_types.types).to eql([tf.string(), tf.string()])
        expect(t2.block_type).to be_nil
      end
    end

    context 'supports lambdas' do
      it 'such that, a required block can be defined and given as an argument' do
        # use a Function as callable
        the_callable = create_min_function_class().new(:closure_scope, :loader)
        the_function = create_function_with_required_block_all_defaults().new(:closure_scope, :loader)
        result = the_function.call({}, 10, the_callable)
        expect(result).to be(the_callable)
      end

      it 'such that, a missing required block when called raises an error' do
        # use a Function as callable
        the_function = create_function_with_required_block_all_defaults().new(:closure_scope, :loader)
        expect do
          the_function.call({}, 10)
        end.to raise_error(ArgumentError,
"function 'test' called with mis-matched arguments
expected:
  test(Integer x, Callable block) - arg count {2}
actual:
  test(Integer) - arg count {1}")
      end

      it 'such that, an optional block can be defined and given as an argument' do
        # use a Function as callable
        the_callable = create_min_function_class().new(:closure_scope, :loader)
        the_function = create_function_with_optional_block_all_defaults().new(:closure_scope, :loader)
        result = the_function.call({}, 10, the_callable)
        expect(result).to be(the_callable)
      end

      it 'such that, an optional block can be omitted when called and gets the value nil' do
        # use a Function as callable
        the_function = create_function_with_optional_block_all_defaults().new(:closure_scope, :loader)
        expect(the_function.call({}, 10)).to be_nil
      end
    end

    context 'provides signature information' do
      it 'about capture rest (varargs)' do
        fc = create_function_with_optionals_and_varargs
        signatures = fc.signatures
        expect(signatures.size).to eql(1)
        signature = signatures[0]
        expect(signature.last_captures_rest?).to be_true
      end

      it 'about optional and required parameters' do
        fc = create_function_with_optionals_and_varargs
        signature = fc.signatures[0]
        expect(signature.args_range).to eql( [2, Puppet::Pops::Types::INFINITY ] )
        expect(signature.infinity?(signature.args_range[1])).to be_true
      end

      it 'about block not being allowed' do
        fc = create_function_with_optionals_and_varargs
        signature = fc.signatures[0]
        expect(signature.block_range).to eql( [ 0, 0 ] )
        expect(signature.block_type).to be_nil
      end

      it 'about required block' do
        fc = create_function_with_required_block_all_defaults
        signature = fc.signatures[0]
        expect(signature.block_range).to eql( [ 1, 1 ] )
        expect(signature.block_type).to_not be_nil
      end

      it 'about optional block' do
        fc = create_function_with_optional_block_all_defaults
        signature = fc.signatures[0]
        expect(signature.block_range).to eql( [ 0, 1 ] )
        expect(signature.block_type).to_not be_nil
      end

      it 'about the type' do
        fc = create_function_with_optional_block_all_defaults
        signature = fc.signatures[0]
        expect(signature.type.class).to be(Puppet::Pops::Types::PCallableType)
      end

      # conditional on Ruby 1.8.7 which does not do parameter introspection
      if Method.method_defined?(:parameters)
        it 'about parameter names obtained from ruby introspection' do
          fc = create_min_function_class
          signature = fc.signatures[0]
          expect(signature.parameter_names).to eql(['x', 'y'])
        end
      end

      it 'about parameter names specified with dispatch' do
        fc = create_min_function_class_using_dispatch
        signature = fc.signatures[0]
        expect(signature.parameter_names).to eql(['a', 'b'])
      end

      it 'about block_name when it is *not* given in the definition' do
        # neither type, nor name
        fc = create_function_with_required_block_all_defaults
        signature = fc.signatures[0]
        expect(signature.block_name).to eql('block')
        # no name given, only type
        fc = create_function_with_required_block_given_type
        signature = fc.signatures[0]
        expect(signature.block_name).to eql('block')
      end

      it 'about block_name when it *is* given in the definition' do
        # neither type, nor name
        fc = create_function_with_required_block_default_type
        signature = fc.signatures[0]
        expect(signature.block_name).to eql('the_block')
        # no name given, only type
        fc = create_function_with_required_block_fully_specified
        signature = fc.signatures[0]
        expect(signature.block_name).to eql('the_block')
      end
    end

    context 'supports calling other functions' do
      before(:all) do
        Puppet.push_context( {:loaders => Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))})
      end

      after(:all) do
        Puppet.pop_context()
      end

      it 'such that, other functions are callable by name' do
        fc = Puppet::Functions.create_function(:test) do
          def test()
            # Call a function available in the puppet system
            call_function('assert_type', 'Integer', 10)
          end
        end
        # initiate the function the same way the loader initiates it
        f = fc.new(:closure_scope, Puppet.lookup(:loaders).puppet_system_loader)
        expect(f.call({})).to eql(10)
      end

      it 'such that, calling a non existing function raises an error' do
        fc = Puppet::Functions.create_function(:test) do
          def test()
            # Call a function not available in the puppet system
            call_function('no_such_function', 'Integer', 'hello')
          end
        end
        # initiate the function the same way the loader initiates it
        f = fc.new(:closure_scope, Puppet.lookup(:loaders).puppet_system_loader)
        expect{f.call({})}.to raise_error(ArgumentError, "Function test(): cannot call function 'no_such_function' - not found")
      end
    end

    context 'supports calling ruby functions with lambda from puppet' do
      before(:all) do
        Puppet.push_context( {:loaders => Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))})
      end

      after(:all) do
        Puppet.pop_context()
      end

      before(:each) do
        Puppet[:strict_variables] = true

        # These must be set since the is 3x logic that triggers on these even if the tests are explicit
        # about selection of parser and evaluator
        #
        Puppet[:parser] = 'future'
        # Puppetx cannot be loaded until the correct parser has been set (injector is turned off otherwise)
        require 'puppetx'
      end

      let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }
      let(:node) { 'node.example.com' }
      let(:scope) { s = create_test_scope_for_node(node); s }

      it 'function with required block can be called' do
        # construct ruby function to call
        fc = Puppet::Functions.create_function('testing::test') do
          dispatch :test do
            param 'Integer', 'x'
            # block called 'the_block', and using "all_callables"
            required_block_param #(all_callables(), 'the_block')
          end
          def test(x, block)
            # call the block with x
            block.call(closure_scope, x)
          end
        end
        # add the function to the loader (as if it had been loaded from somewhere)
        the_loader = loader()
        f = fc.new({}, the_loader)
        loader.add_function('testing::test', f)
        # evaluate a puppet call
        source = "testing::test(10) |$x| { $x+1 }"
        program = parser.parse_string(source, __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect(parser.evaluate(scope, program)).to eql(11)
      end
    end

  end

  def create_noargs_function_class
    f = Puppet::Functions.create_function('test') do
      def test()
        10
      end
    end
  end

  def create_min_function_class
    f = Puppet::Functions.create_function('min') do
      def min(x,y)
        x <= y ? x : y
      end
    end
  end

  def create_max_function_class
    f = Puppet::Functions.create_function('max') do
      def max(x,y)
        x >= y ? x : y
      end
    end
  end

  def create_badly_named_method_function_class
    f = Puppet::Functions.create_function('mix') do
      def mix_up(x,y)
        x <= y ? x : y
      end
    end
  end

  def create_min_function_class_using_dispatch
    f = Puppet::Functions.create_function('min') do
        dispatch :min do
          param 'Numeric', 'a'
          param 'Numeric', 'b'
        end
      def min(x,y)
        x <= y ? x : y
      end
    end
  end

  def create_min_function_class_disptaching_to_two_methods
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', 'a'
        param 'Numeric', 'b'
      end

      dispatch :min_s do
        param 'String', 's1'
        param 'String', 's2'
      end

      def min(x,y)
        x <= y ? x : y
      end

      def min_s(x,y)
        cmp = (x.downcase <=> y.downcase)
        cmp <= 0 ? x : y
      end
    end
  end

  def create_function_with_optionals_and_varargs
    f = Puppet::Functions.create_function('min') do
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_optionals_and_varargs_via_dispatch
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', 'x'
        param 'Numeric', 'y'
        param 'Numeric', 'a'
        param 'Numeric', 'b'
        param 'Numeric', 'c'
        arg_count 2, :default
      end
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_class_injection
    f = Puppet::Functions.create_function('test', Puppet::Functions::InternalFunction) do
      attr_injected Puppet::Pops::Types::TypeFactory.type_of(FunctionAPISpecModule::TestDuck), :test_attr
      attr_injected Puppet::Pops::Types::TypeFactory.string(), :test_attr2, "a_string"
      attr_injected_producer Puppet::Pops::Types::TypeFactory.integer(), :serial, "an_int"

      def test(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_param_injection_regular
    f = Puppet::Functions.create_function('test', Puppet::Functions::InternalFunction) do
      attr_injected Puppet::Pops::Types::TypeFactory.type_of(FunctionAPISpecModule::TestDuck), :test_attr
      attr_injected Puppet::Pops::Types::TypeFactory.string(), :test_attr2, "a_string"
      attr_injected_producer Puppet::Pops::Types::TypeFactory.integer(), :serial, "an_int"

      dispatch :test do
        injected_param Puppet::Pops::Types::TypeFactory.string, 'x', 'a_string'
        injected_producer_param Puppet::Pops::Types::TypeFactory.integer, 'y', 'an_int'
        param 'Scalar', 'a'
        param 'Scalar', 'b'
      end

      def test(x,y,a,b)
        y_produced = y.produce(nil)
        "#{x}! #{a}, and #{b} < #{y_produced} = #{ !!(a < y_produced && b < y_produced)}"
      end
    end
  end

  def create_function_with_required_block_all_defaults
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', 'x'
        # use defaults, any callable, name is 'block'
        required_block_param
      end
      def test(x, block)
        # returns the block to make it easy to test what it got when called
        block
      end
    end
  end

  def create_function_with_required_block_default_type
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', 'x'
        # use defaults, any callable, name is 'block'
        required_block_param 'the_block'
      end
      def test(x, block)
        # returns the block to make it easy to test what it got when called
        block
      end
    end
  end

  def create_function_with_required_block_given_type
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', 'x'
        required_block_param
      end
      def test(x, block)
        # returns the block to make it easy to test what it got when called
        block
      end
    end
  end

  def create_function_with_required_block_fully_specified
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', 'x'
        # use defaults, any callable, name is 'block'
        required_block_param('Callable', 'the_block')
      end
      def test(x, block)
        # returns the block to make it easy to test what it got when called
        block
      end
    end
  end

  def create_function_with_optional_block_all_defaults
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', 'x'
        # use defaults, any callable, name is 'block'
        optional_block_param
      end
      def test(x, block=nil)
        # returns the block to make it easy to test what it got when called
        # a default of nil must be used or the call will fail with a missing parameter
        block
      end
    end
  end

end
