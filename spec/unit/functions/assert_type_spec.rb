require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the assert_type function' do

  after(:all) { Puppet::Pops::Loaders.clear }
  let(:func) do
    loaders = Puppet::Pops::Loaders.new()
    loaders.puppet_system_loader.load(:function, 'assert_type')
  end
  it 'asserts compliant type by returning the value' do
#    loaders = Puppet::Pops::Loaders.new()
#    func = loaders.puppet_system_loader.load(:function, 'assert_type')
    expect(func.call({}, type(String), 'hello world')).to eql('hello world')
  end

  it 'asserts non compliant type by raising an error' do
    expect do
      func.call({}, type(Integer), 'hello world')
    end.to raise_error(ArgumentError, /does not match actual/)
  end

  it 'checks that first argument is a type' do
    expect do
      func.call({}, 10, 10)
    end.to raise_error(ArgumentError, Regexp.new(Regexp.escape(
"function 'assert_type' called with mis-matched arguments
expected:
  assert_type(Type type, Optional[Object] value) - arg count {2}
actual:
  assert_type(Integer, Integer) - arg count {2}")))
  end

  it 'allows the second arg to be undef/nil)' do
    expect do
      func.call({}, optional(String), nil)
    end.to_not raise_error(ArgumentError)
  end

  def optional(type_ref)
    Puppet::Pops::Types::TypeFactory.optional(type(type_ref))
  end

  def type(type_ref)
    Puppet::Pops::Types::TypeFactory.type_of(type_ref)
  end
end
