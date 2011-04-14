#!/usr/bin/env rspec
require 'spec_helper'

describe "the versioncmp function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("versioncmp").should == "function_versioncmp"
  end

  it "should raise a ParseError if there is less than 2 arguments" do
    lambda { @scope.function_versioncmp(["1.2"]) }.should raise_error(Puppet::ParseError)
  end

  it "should raise a ParseError if there is more than 2 arguments" do
    lambda { @scope.function_versioncmp(["1.2", "2.4.5", "3.5.6"]) }.should raise_error(Puppet::ParseError)
  end

  it "should call Puppet::Util::Package.versioncmp (included in scope)" do
    Puppet::Util::Package.expects(:versioncmp).with("1.2", "1.3").returns(-1)

    @scope.function_versioncmp(["1.2", "1.3"])
  end

end
