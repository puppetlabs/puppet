require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops::Types
describe 'The enumeration support' do
  it 'produces an enumerator for Array' do
  expect(Enumeration.enumerator([1,2,3]).respond_to?(:next)).to eql(true)
  end

  it 'produces an enumerator for Hash' do
    expect(Enumeration.enumerator({:a=>1}).respond_to?(:next)).to eql(true)
  end

  it 'produces a char enumerator for String' do
    enum = Enumeration.enumerator("abc")
    expect(enum.respond_to?(:next)).to eql(true)
    expect(enum.next).to eql('a')
  end

  it 'produces an enumerator for integer times' do
    enum = Enumeration.enumerator(2)
    expect(enum.next).to eql(0)
    expect(enum.next).to eql(1)
    expect{enum.next}.to raise_error(StopIteration)
  end

  it 'produces an enumerator for Integer range' do
    range = TypeFactory.range(1,2)
    enum = Enumeration.enumerator(range)
    expect(enum.next).to eql(1)
    expect(enum.next).to eql(2)
    expect{enum.next}.to raise_error(StopIteration)
  end

  it 'does not produce an enumerator for infinite Integer range' do
    range = TypeFactory.range(1,:default)
    enum = Enumeration.enumerator(range)
    expect(enum).to be_nil
    range = TypeFactory.range(:default,2)
    enum = Enumeration.enumerator(range)
    expect(enum).to be_nil
  end

  [3.14, /.*/, true, false, nil, :something].each do |x|
    it "does not produce an enumerator for object of type #{x.class}" do
      enum = Enumeration.enumerator(x)
      expect(enum).to be_nil
    end
  end
end
end
