#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:mailalias) do
  include PuppetSpec::Files

  let :target do tmpfile('mailalias') end
  let :recipient_resource do
    described_class.new(:name => "luke", :recipient => "yay", :target => target)
  end

  let :file_resource do
    described_class.new(:name => "lukefile", :file => "/tmp/afile", :target => target)
  end

  it "should be initially absent as a recipient" do
    recipient_resource.retrieve_resource[:recipient].should == :absent
  end

  it "should be initially absent as an included file" do
    file_resource.retrieve_resource[:file].should == :absent
  end

  it "should try and set the recipient when it does the sync" do
    recipient_resource.retrieve_resource[:recipient].should == :absent
    recipient_resource.property(:recipient).expects(:set).with(["yay"])
    recipient_resource.property(:recipient).sync
  end

  it "should try and set the included file when it does the sync" do
    file_resource.retrieve_resource[:file].should == :absent
    file_resource.property(:file).expects(:set).with("/tmp/afile")
    file_resource.property(:file).sync
  end

  it "should fail when both file and recipient are specified" do
    expect {
      Puppet::Type.type(:mailalias).new(:name => 'x', :file => '/tmp/afile',
					:recipient => 'foo@example.com')
    }.to raise_error Puppet::Error, /cannot specify both a recipient and a file/
  end
end
