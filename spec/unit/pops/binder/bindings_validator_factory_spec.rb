require 'spec_helper'
require 'puppet/pops'

describe 'The bindings validator factory' do
  let(:factory) {  Puppet::Pops::Binder::BindingsValidatorFactory.new() }

  it 'should instantiate a BindingsValidatorFactory' do
    expect(factory.class).to eq(Puppet::Pops::Binder::BindingsValidatorFactory)
  end

  it 'should produce label_provider of class BindingsLabelProvider' do
    expect(factory.label_provider.class).to eq(Puppet::Pops::Binder::BindingsLabelProvider)
  end

  it 'should produce validator of class BindingsChecker' do
    expect(factory.validator(Puppet::Pops::Validation::Acceptor.new()).class).to eq(Puppet::Pops::Binder::BindingsChecker)
  end
end
