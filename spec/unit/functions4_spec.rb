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
      @constants = {}
    end

    def add_function(name, function)
      set_entry(Puppet::Pops::Loader::Loader::TypedName.new(:function, name), function, __FILE__)
    end

    def add_type(name, type)
      set_entry(Puppet::Pops::Loader::Loader::TypedName.new(:type, name), type, __FILE__)
    end

    def set_entry(typed_name, value, origin = nil)
      @constants[typed_name] = Puppet::Pops::Loader::Loader::NamedEntry.new(typed_name, value, origin)
    end

    # override StaticLoader
    def load_constant(typed_name)
      @constants[typed_name]
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

  it 'refuses to create functions with parameters that are not named with a symbol' do
    expect do
      Puppet::Functions.create_function('testing') do
        dispatch :test do
          param 'Integer', 'not_symbol'
        end
        def test(x)
        end
      end
    end.to raise_error(ArgumentError, /Parameter name argument must be a Symbol/)
  end

  it 'a function without arguments can be defined and called without dispatch declaration' do
    f = create_noargs_function_class()
    func = f.new(:closure_scope, :loader)
    expect(func.call({})).to eql(10)
  end

  it 'an error is raised when calling a no arguments function with arguments' do
    f = create_noargs_function_class()
    func = f.new(:closure_scope, :loader)
    expect{func.call({}, 'surprise')}.to raise_error(ArgumentError, "'test' expects no arguments, got 1")
  end

  it 'a simple function can be called' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
    expect(func.call({}, 10,20)).to eql(10)
  end

  it 'an error is raised if called with too few arguments' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
    signature = 'Any x, Any y'
    expect do
      func.call({}, 10)
    end.to raise_error(ArgumentError, "'min' expects 2 arguments, got 1")
  end

  it 'an error is raised if called with too many arguments' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
    signature = 'Any x, Any y'
    expect do
      func.call({}, 10, 10, 10)
    end.to raise_error(ArgumentError, "'min' expects 2 arguments, got 3")
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
      expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
      expect do
        func.call({}, 10, 'ten')
      end.to raise_error(ArgumentError, "'min' parameter 'b' expects a Numeric value, got String")
    end

    it 'an error includes optional indicators for last element' do
      f = create_function_with_optionals_and_repeated_via_multiple_dispatch()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
      expect do
        func.call({}, 3, 10, 3, "4")
      end.to raise_error(ArgumentError, "'min' expects one of:
  (Numeric x, Numeric y, Numeric a?, Numeric b?, Numeric c*)
    rejected: parameter 'b' expects a Numeric value, got String
  (String x, String y, String a+)
    rejected: parameter 'x' expects a String value, got Integer")
    end

    it 'can create optional repeated parameter' do
      f = create_function_with_repeated
      func = f.new(:closure_scope, :loader)
      expect(func.call({})).to eql(0)
      expect(func.call({}, 1)).to eql(1)
      expect(func.call({}, 1, 2)).to eql(2)

      f = create_function_with_optional_repeated
      func = f.new(:closure_scope, :loader)
      expect(func.call({})).to eql(0)
      expect(func.call({}, 1)).to eql(1)
      expect(func.call({}, 1, 2)).to eql(2)
    end

    it 'can create required repeated parameter' do
      f = create_function_with_required_repeated
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 1)).to eql(1)
      expect(func.call({}, 1, 2)).to eql(2)
      expect { func.call({}) }.to raise_error(ArgumentError, "'count_args' expects at least 1 argument, got none")
    end

    it 'can create scope_param followed by repeated  parameter' do
      f = create_function_with_scope_param_required_repeat
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 'yay', 1,2,3)).to eql([{}, 'yay',1,2,3])
    end

    it 'a function can use inexact argument mapping' do
      f = create_function_with_inexact_dispatch
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 3,4,5)).to eql([Fixnum, Fixnum, Fixnum])
      expect(func.call({}, 'Apple', 'Banana')).to eql([String, String])
    end

    it 'a function can be created using dispatch and called' do
      f = create_min_function_class_disptaching_to_two_methods()
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 3,4)).to eql(3)
      expect(func.call({}, 'Apple', 'Banana')).to eql('Apple')
    end

    it 'a function can not be created with parameters declared after a repeated parameter' do
      expect { create_function_with_param_after_repeated }.to raise_error(ArgumentError, 'Parameters cannot be added after a repeated parameter')
    end

    it 'a function can not be created with required parameters declared after optional ones' do
      expect { create_function_with_rq_after_opt }.to raise_error(ArgumentError, 'A required parameter cannot be added after an optional parameter')
    end

    it 'a function can not be created with required repeated parameters declared after optional ones' do
      expect { create_function_with_rq_repeated_after_opt }.to raise_error(ArgumentError, 'A required repeated parameter cannot be added after an optional parameter')
    end

    it 'an error is raised with reference to multiple methods when called with mis-matched arguments' do
      f = create_min_function_class_disptaching_to_two_methods()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_truthy
      expect do
        func.call({}, 10, '20')
      end.to raise_error(ArgumentError, "'min' expects one of:
  (Numeric a, Numeric b)
    rejected: parameter 'b' expects a Numeric value, got String
  (String s1, String s2)
    rejected: parameter 's1' expects a String value, got Integer")
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
        the_function = create_function_with_required_block_all_defaults().new(:closure_scope, :loader)
        result = the_function.call({}, 7) { |a,b| a < b ? a : b }
        expect(result).to eq(7)
      end

      it 'such that, a missing required block when called raises an error' do
        the_function = create_function_with_required_block_all_defaults().new(:closure_scope, :loader)
        expect do
          the_function.call({}, 10)
        end.to raise_error(ArgumentError, "'test' expects a block")
      end

      it 'such that, an optional block can be defined and given as an argument' do
        the_function = create_function_with_optional_block_all_defaults().new(:closure_scope, :loader)
        result = the_function.call({}, 4) { |a,b| a < b ? a : b }
        expect(result).to eql(4)
      end

      it 'such that, an optional block can be omitted when called and gets the value nil' do
        the_function = create_function_with_optional_block_all_defaults().new(:closure_scope, :loader)
        expect(the_function.call({}, 2)).to be_nil
      end

      it 'such that, a scope can be injected and a block can be used' do
        the_function = create_function_with_scope_required_block_all_defaults().new(:closure_scope, :loader)
        expect(the_function.call({}, 1) { |a,b| a < b ? a : b }).to eql(1)
      end
    end

    context 'provides signature information' do
      it 'about capture rest (varargs)' do
        fc = create_function_with_optionals_and_repeated
        signatures = fc.signatures
        expect(signatures.size).to eql(1)
        signature = signatures[0]
        expect(signature.last_captures_rest?).to be_truthy
      end

      it 'about optional and required parameters' do
        fc = create_function_with_optionals_and_repeated
        signature = fc.signatures[0]
        expect(signature.args_range).to eql( [2, Float::INFINITY ] )
        expect(signature.infinity?(signature.args_range[1])).to be_truthy
      end

      it 'about block not being allowed' do
        fc = create_function_with_optionals_and_repeated
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

      it 'about parameter names obtained from ruby introspection' do
        fc = create_min_function_class
        signature = fc.signatures[0]
        expect(signature.parameter_names).to eql(['x', 'y'])
      end

      it 'about parameter names specified with dispatch' do
        fc = create_min_function_class_using_dispatch
        signature = fc.signatures[0]
        expect(signature.parameter_names).to eql([:a, :b])
      end

      it 'about block_name when it is *not* given in the definition' do
        # neither type, nor name
        fc = create_function_with_required_block_all_defaults
        signature = fc.signatures[0]
        expect(signature.block_name).to eql(:block)
        # no name given, only type
        fc = create_function_with_required_block_given_type
        signature = fc.signatures[0]
        expect(signature.block_name).to eql(:block)
      end

      it 'about block_name when it *is* given in the definition' do
        # neither type, nor name
        fc = create_function_with_required_block_default_type
        signature = fc.signatures[0]
        expect(signature.block_name).to eql(:the_block)
        # no name given, only type
        fc = create_function_with_required_block_fully_specified
        signature = fc.signatures[0]
        expect(signature.block_name).to eql(:the_block)
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
        fc = Puppet::Functions.create_function('test') do
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
        fc = Puppet::Functions.create_function('test') do
          def test()
            # Call a function not available in the puppet system
            call_function('no_such_function', 'Integer', 'hello')
          end
        end
        # initiate the function the same way the loader initiates it
        f = fc.new(:closure_scope, Puppet.lookup(:loaders).puppet_system_loader)
        expect{f.call({})}.to raise_error(ArgumentError, "Function test(): Unknown function: 'no_such_function'")
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
      end

      let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }
      let(:node) { 'node.example.com' }
      let(:scope) { s = create_test_scope_for_node(node); s }

      it 'function with required block can be called' do
        # construct ruby function to call
        fc = Puppet::Functions.create_function('testing::test') do
          dispatch :test do
            param 'Integer', :x
            # block called 'the_block', and using "all_callables"
            required_block_param #(all_callables(), 'the_block')
          end
          def test(x)
            # call the block with x
            yield(x)
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

    context 'can use a loader when parsing types in function dispatch, and' do
      let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }

      it 'resolve a referenced Type alias' do
        the_loader = loader()
        the_loader.add_type('myalias', type_alias_t('MyAlias', 'Integer'))
        here = get_binding(the_loader)
        fc = eval(<<-CODE, here)
          Puppet::Functions.create_function('testing::test') do
            dispatch :test do
              param 'MyAlias', :x
            end
            def test(x)
              x
            end
          end
        CODE
        the_loader.add_function('testing::test', fc.new({}, the_loader))
        program = parser.parse_string('testing::test(10)', __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect(parser.evaluate({}, program)).to eql(10)
      end

      it 'reports a reference to an unresolved type' do
        the_loader = loader()
        here = get_binding(the_loader)
        fc = eval(<<-CODE, here)
          Puppet::Functions.create_function('testing::test') do
            dispatch :test do
              param 'MyAlias', :x
            end
            def test(x)
              x
            end
          end
        CODE
        the_loader.add_function('testing::test', fc.new({}, the_loader))
        program = parser.parse_string('testing::test(10)', __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect { parser.evaluate({}, program) }.to raise_error(Puppet::Error, /parameter 'x' references an unresolved type 'MyAlias'/)
      end

      it 'create local Type aliases' do
        the_loader = loader()
        here = get_binding(the_loader)
        fc = eval(<<-CODE, here)
          Puppet::Functions.create_function('testing::test') do
            local_types do
              type 'MyType = Array[Integer]'
            end
            dispatch :test do
              param 'MyType', :x
            end
            def test(x)
              x
            end
          end
        CODE
        the_loader.add_function('testing::test', fc.new({}, the_loader))
        program = parser.parse_string('testing::test([10,20])', __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect(parser.evaluate({}, program)).to eq([10,20])
      end

      it 'create nested local Type aliases' do
        the_loader = loader()
        here = get_binding(the_loader)
        fc = eval(<<-CODE, here)
          Puppet::Functions.create_function('testing::test') do
            local_types do
              type 'InnerType = Array[Integer]'
              type 'OuterType = Hash[String,InnerType]'
            end
            dispatch :test do
              param 'OuterType', :x
            end
            def test(x)
              x
            end
          end
        CODE
        the_loader.add_function('testing::test', fc.new({}, the_loader))
        program = parser.parse_string("testing::test({'x' => [10,20]})", __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect(parser.evaluate({}, program)).to eq({'x' => [10,20]})
      end

      it 'create self referencing local Type aliases' do
        the_loader = loader()
        here = get_binding(the_loader)
        fc = eval(<<-CODE, here)
          Puppet::Functions.create_function('testing::test') do
            local_types do
              type 'Tree = Hash[String,Variant[String,Tree]]'
            end
            dispatch :test do
              param 'Tree', :x
            end
            def test(x)
              x
            end
          end
        CODE
        the_loader.add_function('testing::test', fc.new({}, the_loader))
        program = parser.parse_string("testing::test({'x' => {'y' => 'n'}})", __FILE__)
        Puppet::Pops::Adapters::LoaderAdapter.adapt(program.model).loader = the_loader
        expect(parser.evaluate({}, program)).to eq({'x' => {'y' => 'n'}})
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
          param 'Numeric', :a
          param 'Numeric', :b
        end
      def min(x,y)
        x <= y ? x : y
      end
    end
  end

  def create_min_function_class_disptaching_to_two_methods
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', :a
        param 'Numeric', :b
      end

      dispatch :min_s do
        param 'String', :s1
        param 'String', :s2
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

  def create_function_with_optionals_and_repeated
    f = Puppet::Functions.create_function('min') do
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_optionals_and_repeated_via_dispatch
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', :x
        param 'Numeric', :y
        optional_param 'Numeric', :a
        optional_param 'Numeric', :b
        repeated_param 'Numeric', :c
      end
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_optionals_and_repeated_via_multiple_dispatch
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', :x
        param 'Numeric', :y
        optional_param 'Numeric', :a
        optional_param 'Numeric', :b
        repeated_param 'Numeric', :c
      end
      dispatch :min do
        param 'String', :x
        param 'String', :y
        required_repeated_param 'String', :a
      end
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_required_repeated_via_dispatch
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param 'Numeric', :x
        param 'Numeric', :y
        required_repeated_param 'Numeric', :z
      end
      def min(x,y, *z)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_repeated
    f = Puppet::Functions.create_function('count_args') do
      dispatch :count_args do
        repeated_param 'Any', :c
      end
      def count_args(*c)
        c.size
      end
    end
  end

  def create_function_with_optional_repeated
    f = Puppet::Functions.create_function('count_args') do
      dispatch :count_args do
        optional_repeated_param 'Any', :c
      end
      def count_args(*c)
        c.size
      end
    end
  end

  def create_function_with_required_repeated
    f = Puppet::Functions.create_function('count_args') do
      dispatch :count_args do
        required_repeated_param 'Any', :c
      end
      def count_args(*c)
        c.size
      end
    end
  end

  def create_function_with_inexact_dispatch
    f = Puppet::Functions.create_function('t1') do
      dispatch :t1 do
        param 'Numeric', :x
        param 'Numeric', :y
        repeated_param 'Numeric', :z
      end
      dispatch :t1 do
        param 'String', :x
        param 'String', :y
        repeated_param 'String', :z
      end
      def t1(first, *x)
        [first.class, *x.map {|e|e.class}]
      end
    end
  end

  def create_function_with_rq_after_opt
    f = Puppet::Functions.create_function('t1') do
      dispatch :t1 do
        optional_param 'Numeric', :x
        param 'Numeric', :y
      end
      def t1(*x)
        x
      end
    end
  end

  def create_function_with_rq_repeated_after_opt
    f = Puppet::Functions.create_function('t1') do
      dispatch :t1 do
        optional_param 'Numeric', :x
        required_repeated_param 'Numeric', :y
      end
      def t1(x, *y)
        x
      end
    end
  end

  def create_function_with_param_after_repeated
    f = Puppet::Functions.create_function('t1') do
      dispatch :t1 do
        repeated_param 'Numeric', :x
        param 'Numeric', :y
      end
      def t1(*x)
        x
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
        injected_param Puppet::Pops::Types::TypeFactory.string, :x, 'a_string'
        injected_producer_param Puppet::Pops::Types::TypeFactory.integer, :y, 'an_int'
        param 'Scalar', :a
        param 'Scalar', :b
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
        param 'Integer', :x
        # use defaults, any callable, name is 'block'
        block_param
      end
      def test(x)
        yield(8,x)
      end
    end
  end

  def create_function_with_scope_required_block_all_defaults
    f = Puppet::Functions.create_function('test', Puppet::Functions::InternalFunction) do
      dispatch :test do
        scope_param
        param 'Integer', :x
        # use defaults, any callable, name is 'block'
        required_block_param
      end
      def test(scope, x)
        yield(3,x)
      end
    end
  end

  def create_function_with_required_block_default_type
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', :x
        # use defaults, any callable, name is 'block'
        required_block_param :the_block
      end
      def test(x)
        yield
      end
    end
  end

  def create_function_with_scope_param_required_repeat
    f = Puppet::Functions.create_function('test', Puppet::Functions::InternalFunction) do
      dispatch :test do
        scope_param
        param 'Any', :extra
        repeated_param 'Any', :the_block
      end
      def test(scope, *args)
        [scope, *args]
      end
    end
  end

  def create_function_with_required_block_given_type
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', :x
        required_block_param
      end
      def test(x)
        yield
      end
    end
  end

  def create_function_with_required_block_fully_specified
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', :x
        # use defaults, any callable, name is 'block'
        required_block_param('Callable', :the_block)
      end
      def test(x)
        yield
      end
    end
  end

  def create_function_with_optional_block_all_defaults
    f = Puppet::Functions.create_function('test') do
      dispatch :test do
        param 'Integer', :x
        # use defaults, any callable, name is 'block'
        optional_block_param
      end
      def test(x)
        yield(5,x) if block_given?
      end
    end
  end

  def type_alias_t(name, type_string)
    type_expr = Puppet::Pops::Parser::EvaluatingParser.new.parse_string(type_string).current
    Puppet::Pops::Types::TypeFactory.type_alias(name, type_expr)
  end

  def get_binding(loader_injected_arg)
    binding
  end
end
