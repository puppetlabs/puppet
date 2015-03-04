#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/node/plain'

describe Puppet::Node::Plain do
  let(:nodename) { "mynode" }
  let(:fact_values) { {:afact => "a value"} }
  let(:facts) { Puppet::Node::Facts.new(nodename, fact_values) }
  let(:environment) { Puppet::Node::Environment.create(:myenv, []) }
  let(:request) { Puppet::Indirector::Request.new(:node, :find, nodename, nil, :environment => environment) }
  let(:node_indirection) { Puppet::Node::Plain.new }

  before do
    Puppet::Node::Facts.indirection.expects(:find).with(nodename, :environment => environment).returns(facts)
  end

  it "merges facts into the node" do
    expect(node_indirection.find(request).parameters).to include(fact_values)
  end

  it "should set the node environment from the request" do
    expect(node_indirection.find(request).environment).to eq(environment)
  end

end
