#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/log'

describe Puppet::Util::Log.desttypes[:report] do
  before do
    @dest = Puppet::Util::Log.desttypes[:report]
  end

  it "should require a report at initialization" do
    @dest.new("foo").report.should == "foo"
  end

  it "should send new messages to the report" do
    report = mock 'report'
    dest = @dest.new(report)

    report.expects(:<<).with("my log")

    dest.handle "my log"
  end
end


describe Puppet::Util::Log.desttypes[:file] do
  before do
    File.stubs(:open)           # prevent actually creating the file
    @class = Puppet::Util::Log.desttypes[:file]
  end

  it "should default to autoflush false" do
    @class.new('/tmp/log').autoflush.should == false
  end
end

