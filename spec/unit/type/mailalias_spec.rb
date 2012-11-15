#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:mailalias) do
  include PuppetSpec::Files

  let :target do tmpfile('mailalias') end
  let :resource do
    described_class.new(:name => "luke", :recipient => "yay", :target => target)
  end

  it "should be initially absent" do
    resource.retrieve_resource[:recipient].should == :absent
  end

  it "should try and set the recipient when it does the sync" do
    resource.retrieve_resource[:recipient].should == :absent
    resource.property(:recipient).expects(:set).with(["yay"])
    resource.property(:recipient).sync
  end
end
