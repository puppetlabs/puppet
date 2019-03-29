require 'spec_helper'
require 'puppet/indirector/plain'

describe Puppet::Indirector::Plain do
  before do
    allow(Puppet::Indirector::Terminus).to receive(:register_terminus_class)
    @model = double('model')
    @indirection = double('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
    allow(Puppet::Indirector::Indirection).to receive(:instance).and_return(@indirection)

    module Testing; end
    @plain_class = class Testing::MyPlain < Puppet::Indirector::Plain
      self
    end

    @searcher = @plain_class.new

    @request = double('request', :key => "yay")
  end

  it "should return return an instance of the indirected model" do
    object = double('object')
    expect(@model).to receive(:new).with(@request.key).and_return(object)
    expect(@searcher.find(@request)).to equal(object)
  end
end
