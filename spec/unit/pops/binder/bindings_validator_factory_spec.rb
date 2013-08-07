require 'spec_helper'
require 'puppet/pops'

describe 'The bindings validator factory' do
  let(:factory) {  Puppet::Pops::Binder::BindingsValidatorFactory.new() }

  it 'should instantiate a BindingsValidatorFactory' do
    factory.class.should == Puppet::Pops::Binder::BindingsValidatorFactory
  end

  it 'should produce label_provider of class BindingsLabelProvider' do
    factory.label_provider.class.should == Puppet::Pops::Binder::BindingsLabelProvider
  end

  it 'should produce validator of class BindingsChecker' do
    factory.validator(Puppet::Pops::Validation::Acceptor.new()).class.should == Puppet::Pops::Binder::BindingsChecker
  end
end
