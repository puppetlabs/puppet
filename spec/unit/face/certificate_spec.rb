#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

require 'puppet/ssl/host'

describe Puppet::Face[:certificate, '0.0.1'] do
  it "should have a ca-location option" do
    subject.should be_option :ca_location
  end

  it "should set the ca location when invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    Puppet::SSL::Host.indirection.expects(:save)
    subject.sign "hello, friend", :ca_location => :local
  end

  it "(#7059) should set the ca location when an inherited action is invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    subject.indirection.expects(:find)
    subject.find "hello, friend", :ca_location => :local
  end

  it "should validate the option as required" do
    expect do
      subject.find 'hello, friend'
    end.to raise_exception ArgumentError, /required/i
  end

  it "should validate the option as a supported value" do
    expect do
      subject.find 'hello, friend', :ca_location => :foo
    end.to raise_exception ArgumentError, /valid values/i
  end
end
