#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/facts/inventory_service'

describe Puppet::Node::Facts::InventoryService do
  it "should suppress failures and warn when saving facts" do
    facts = Puppet::Node::Facts.new('foo')
    request = Puppet::Indirector::Request.new(:facts, :save, nil, facts)

    Net::HTTP.any_instance.stubs(:put).raises(Errno::ECONNREFUSED)

    Puppet.expects(:warning).with do |msg|
      msg =~ /Could not upload facts for foo to inventory service/
    end

    expect {
      subject.save(request)
    }.to_not raise_error
  end
end
