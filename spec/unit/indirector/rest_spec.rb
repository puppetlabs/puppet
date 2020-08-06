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
  let(:terminus) { Puppet::TestModel::Rest.new }

  before :each do
    terminus.indirection.terminus_class = :rest
  end

  it "raises when find is called" do
    expect {
      terminus.find(Puppet::Indirector::Request.new(:test_model, :find, 'foo', nil))
    }.to raise_error(NotImplementedError)
  end

  it "raises when head is called" do
    expect {
      terminus.head(Puppet::Indirector::Request.new(:test_model, :head, 'foo', nil))
    }.to raise_error(NotImplementedError)
  end

  it "raises when search is called" do
    expect {
      terminus.search(Puppet::Indirector::Request.new(:test_model, :search, 'foo', nil))
    }.to raise_error(NotImplementedError)
  end

  it "raises when save is called" do
    expect {
      terminus.save(Puppet::Indirector::Request.new(:test_model, :save, 'foo', Puppet::TestModel.new))
    }.to raise_error(NotImplementedError)
  end

  it "raises when destroy is called" do
    expect {
      terminus.destroy(Puppet::Indirector::Request.new(:test_model, :destroy, 'foo', nil))
    }.to raise_error(NotImplementedError)
  end
end
