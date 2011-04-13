#!/usr/bin/env rspec
require 'spec_helper'

describe "the 'tag' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
    @scope.stubs(:environment).returns(nil)
  end

  it "should exist" do
    Puppet::Parser::Functions.function(:tag).should == "function_tag"
  end

  it "should tag the resource with any provided tags" do
    resource = Puppet::Parser::Resource.new(:file, "/file", :scope => @scope)
    @scope.expects(:resource).returns resource

    @scope.function_tag ["one", "two"]

    resource.should be_tagged("one")
    resource.should be_tagged("two")
  end
end
