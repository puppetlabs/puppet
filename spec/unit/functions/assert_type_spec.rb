require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the assert_type function' do

  after(:all) { Puppet::Pops::Loaders.clear }

  around(:each) do |example|
    loaders = Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))
    Puppet.override({:loaders => loaders}, "test-example") do
      example.run
    end
  end

  let(:func) do
    Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'assert_type')
  end

  it 'asserts compliant type by returning the value' do
    expect(func.call({}, type(String), 'hello world')).to eql('hello world')
  end

  it 'accepts type given as a String' do
    expect(func.call({}, 'String', 'hello world')).to eql('hello world')
  end

  it 'asserts non compliant type by raising an error' do
    expect do
      func.call({}, type(Integer), 'hello world')
    end.to raise_error(Puppet::ParseError, /does not match actual/)
  end

  it 'checks that first argument is a type' do
    expect do
      func.call({}, 10, 10)
    end.to raise_error(ArgumentError, Regexp.new(Regexp.escape(
"function 'assert_type' called with mis-matched arguments
expected one of:
  assert_type(Type type, Any value, Callable[Type, Type] block {0,1}) - arg count {2,3}
  assert_type(String type_string, Any value, Callable[Type, Type] block {0,1}) - arg count {2,3}
actual:
  assert_type(Integer, Integer) - arg count {2}")))
  end

  it 'allows the second arg to be undef/nil)' do
    expect do
      func.call({}, optional(String), nil)
    end.to_not raise_error
  end

  it 'can be called with a callable that receives a specific type' do
    expected, actual = func.call({}, optional(String), 1, create_callable_2_args_unit)
    expect(expected.to_s).to eql('Optional[String]')
    expect(actual.to_s).to eql('Integer[1, 1]')
  end

  def optional(type_ref)
    Puppet::Pops::Types::TypeFactory.optional(type(type_ref))
  end

  def type(type_ref)
    Puppet::Pops::Types::TypeFactory.type_of(type_ref)
  end

  def create_callable_2_args_unit()
    Puppet::Functions.create_function(:func) do
      dispatch :func do
        param 'Type', 'expected'
        param 'Type', 'actual'
      end

      def func(expected, actual)
        [expected, actual]
      end
    end.new({}, nil)
  end
end
