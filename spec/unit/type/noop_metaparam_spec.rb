#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/type'

describe Puppet::Type.type(:file).attrclass(:noop) do
  before do
    Puppet.settings.stubs(:use)
    @file = Puppet::Type.newfile :path => "/what/ever"
  end

  it "should accept true as a value" do
    lambda { @file[:noop] = true }.should_not raise_error
  end

  it "should accept false as a value" do
    lambda { @file[:noop] = false }.should_not raise_error
  end

  describe "when set on a resource" do
    it "should default to the :noop setting" do
      Puppet.settings.expects(:value).with(:noop).returns "myval"
      @file.noop.should == "myval"
    end

    it "should prefer true values from the attribute" do
      @file[:noop] = true
      @file.noop.should be_true
    end

    it "should prefer false values from the attribute" do
      @file[:noop] = false
      @file.noop.should be_false
    end
  end
end
