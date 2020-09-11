require 'spec_helper'
require 'puppet/indirector/rest'

class Puppet::TestModel
  extend Puppet::Indirector
  indirects :test_model
end

# The subclass must not be all caps even though the superclass is
class Puppet::TestModel::Rest < Puppet::Indirector::REST
end


describe Puppet::Indirector::REST do
  before :each do
    Puppet::TestModel.indirection.terminus_class = :rest
  end

  it "raises when find is called" do
    expect {
      Puppet::TestModel.indirection.find('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when head is called" do
    expect {
      Puppet::TestModel.indirection.head('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when search is called" do
    expect {
      Puppet::TestModel.indirection.search('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when save is called" do
    expect {
      Puppet::TestModel.indirection.save(Puppet::TestModel.new, 'foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when destroy is called" do
    expect {
      Puppet::TestModel.indirection.destroy('foo')
    }.to raise_error(NotImplementedError)
  end
end
