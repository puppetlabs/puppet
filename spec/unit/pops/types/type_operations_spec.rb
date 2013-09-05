require 'spec_helper'
require 'puppet/pops'

describe 'operations on types' do

  describe 'Puppet::Pops::Types::PPatternType' do
    it 'can create a regular expression via the [] operator' do
      result = Puppet::Pops::Types::PPatternType.new()['a*']
      expect(result.class).to eql(Regexp)
      expect(result).to eql(Regexp.new('a*'))
    end
  end

  describe 'the Puppet::Pops::Types::PCatalog subtypes' do
    it 'can create an unspecific type by using the [] operator without arguments' do
      x = Puppet::Pops::Types::TypeFactory.host_class()
      expect(x[]).to be_the_type(Puppet::Pops::Types::TypeFactory.host_class())

      x = Puppet::Pops::Types::TypeFactory.resource()
      expect(x[]).to be_the_type(Puppet::Pops::Types::TypeFactory.resource())

      x = Puppet::Pops::Types::TypeFactory.resource('File')
      expect(x[]).to be_the_type(Puppet::Pops::Types::TypeFactory.resource('File'))
    end

    it 'can create a specific class by using [name] on PHostClassType with given class name' do
      x = Puppet::Pops::Types::TypeFactory.host_class()
      expect(x['a']).to be_the_type(Puppet::Pops::Types::TypeFactory.host_class('a'))
    end

    it 'can create a specific resource reference by using [name] on a PResourceType with given type name' do
      x = Puppet::Pops::Types::TypeFactory.resource('File')
      expect(x['a']).to be_the_type(Puppet::Pops::Types::TypeFactory.resource('File', 'a'))
    end

    it 'can create an Array of class references' do
      x = Puppet::Pops::Types::TypeFactory.host_class()
      result = x['a', 'b', 'c']
      expect(result.class).to eql(Array)
      expect(result[0]).to be_the_type(Puppet::Pops::Types::TypeFactory.host_class('a'))
      expect(result[1]).to be_the_type(Puppet::Pops::Types::TypeFactory.host_class('b'))
      expect(result[2]).to be_the_type(Puppet::Pops::Types::TypeFactory.host_class('c'))
    end

    it 'can create an Array of Resource references' do
      x = Puppet::Pops::Types::TypeFactory.resource('F')
      result = x['a', 'b', 'c']
      expect(result.class).to eql(Array)
      expect(result[0]).to be_the_type(Puppet::Pops::Types::TypeFactory.resource('F', 'a'))
      expect(result[1]).to be_the_type(Puppet::Pops::Types::TypeFactory.resource('F', 'b'))
      expect(result[2]).to be_the_type(Puppet::Pops::Types::TypeFactory.resource('F', 'c'))
    end

    it 'checks error conditions' do
      x = Puppet::Pops::Types::TypeFactory.host_class('a')
      expect{x['b']}.to raise_error(/Cannot create new Class references from a specific Class reference/)

      x = Puppet::Pops::Types::TypeFactory.resource('File', 'foo')
      expect{x['b']}.to raise_error(/Cannot create new Resource references from a specific Resource reference/)

      x = Puppet::Pops::Types::TypeFactory.resource()
      expect{x['b']}.to raise_error(/A Resource reference without type name can not produce Resource references/)
    end
  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message_for_should do |actual|
      "expected #{calc.string(type)}, but was #{calc.string(actual)}"
    end
  end

end