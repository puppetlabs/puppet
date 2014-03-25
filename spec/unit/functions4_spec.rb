require 'spec_helper'
require 'puppet/pops'

module FunctionAPISpecModule
  class TestDuck
  end
end

describe 'the 4x function api' do
  include FunctionAPISpecModule

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
      'Object{2}'
    else
      'Object x, Object y'
    end
    expect do
      func.call({}, 10)
    end.to raise_error(ArgumentError, Regexp.new(Regexp.escape("function 'min' called with mis-matched arguments
expected:
  min(#{signature}) - arg count {2}
actual:
  min(Integer) - arg count {1}")))
  end

  it 'an error is raised if called with too many arguments' do
    f = create_min_function_class()
    # TODO: Bogus parameters, not yet used
    func = f.new(:closure_scope, :loader)
    expect(func.is_a?(Puppet::Functions::Function)).to be_true
    signature = if RUBY_VERSION =~ /^1\.8/
      'Object{2}'
    else
      'Object x, Object y'
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
    expect(d1.dispatchers[0].visitor).to_not eql(d2.dispatchers[0].visitor.name)
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
        'Object{2,}'
      else
        'Object x, Object y, Object a?, Object b?, Object c{0,}'
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

    it 'a function can be created using polymorph dispatch and called' do
      f = create_function_with_polymorph_dispatch()
      func = f.new(:closure_scope, :loader)
      expect(func.call({}, 3,4)).to eql(3)
      expect(func.call({}, 'Apple', 'Banana')).to eql('Apple')
    end

    it 'an error is raised with reference to polymorph method when called with mis-matched arguments' do
      f = create_function_with_polymorph_dispatch()
      # TODO: Bogus parameters, not yet used
      func = f.new(:closure_scope, :loader)
      expect(func.is_a?(Puppet::Functions::Function)).to be_true
      expect do
        func.call({}, 10, 10, 10)
      end.to raise_error(ArgumentError,
"function 'min' called with mis-matched arguments
expected:
  min(Scalar a, Scalar b) - arg count {2}
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

      it 'parameters can be injected and woven with polymorph dispatch' do
        f1 = create_function_with_param_injection_poly()
        f = f1.new(:closure_scope, :loader)
        expect(f.call(nil, 10, 20)).to eql("evoe! 10, and 20 < 42 = true")
        expect(f.call(nil, 50, 20)).to eql("evoe! 50, and 20 < 42 = false")
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
          param Numeric, 'a'
          param Numeric, 'b'
        end
      def min(x,y)
        x <= y ? x : y
      end
    end
  end

  def create_min_function_class_disptaching_to_two_methods
    f = Puppet::Functions.create_function('min') do
      dispatch :min do
        param Numeric, 'a'
        param Numeric, 'b'
      end

      dispatch :min_s do
        param String, 's1'
        param String, 's2'
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
        param Numeric, 'x'
        param Numeric, 'y'
        param Numeric, 'a'
        param Numeric, 'b'
        param Numeric, 'c'
        arg_count 2, :default
      end
      def min(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_polymorph_dispatch
    f = Puppet::Functions.create_function('min') do
      dispatch_polymorph :min do
        param scalar, 'a'
        param scalar, 'b'
      end

      def min_Numeric(x,y)
        x <= y ? x : y
      end

      def min_String(x,y)
        cmp = (x.downcase <=> y.downcase)
        cmp <= 0 ? x : y
      end

      def min_Object(x,y)
        raise ArgumentError, "min(): Only Numeric and String arguments are supported"
      end
    end
  end

  def create_function_with_class_injection
    f = Puppet::Functions.create_function('test') do
      attr_injected type_of(FunctionAPISpecModule::TestDuck), :test_attr
      attr_injected string(), :test_attr2, "a_string"
      attr_injected_producer integer(), :serial, "an_int"

      def test(x,y,a=1, b=1, *c)
        x <= y ? x : y
      end
    end
  end

  def create_function_with_param_injection_poly
    f = Puppet::Functions.create_function('test') do
      attr_injected type_of(FunctionAPISpecModule::TestDuck), :test_attr
      attr_injected string(), :test_attr2, "a_string"
      attr_injected_producer integer(), :serial, "an_int"

      dispatch_polymorph :test do
        injected_param string, 'x', 'a_string'
        injected_producer_param integer, 'y', 'an_int'
        param scalar, 'a'
        param scalar, 'b'
      end

      def test_String(x,y,a,b)
        y_produced = y.produce(nil)
        "#{x}! #{a}, and #{b} < #{y_produced} = #{ !!(a < y_produced && b < y_produced)}"
      end
    end
  end

  def create_function_with_param_injection_regular
    f = Puppet::Functions.create_function('test') do
      attr_injected type_of(FunctionAPISpecModule::TestDuck), :test_attr
      attr_injected string(), :test_attr2, "a_string"
      attr_injected_producer integer(), :serial, "an_int"

      dispatch :test do
        injected_param string, 'x', 'a_string'
        injected_producer_param integer, 'y', 'an_int'
        param scalar, 'a'
        param scalar, 'b'
      end

      def test(x,y,a,b)
        y_produced = y.produce(nil)
        "#{x}! #{a}, and #{b} < #{y_produced} = #{ !!(a < y_produced && b < y_produced)}"
      end
    end
  end

end