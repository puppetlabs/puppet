#!/usr/bin/env rspec
require 'spec_helper'

describe "the fqdn_rand function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("fqdn_rand").should == "function_fqdn_rand"
  end

  it "should handle 0 arguments" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    lambda { @scope.function_fqdn_rand([]) }.should_not raise_error(Puppet::ParseError)
  end

  it "should handle 1 argument'}" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    lambda { @scope.function_fqdn_rand([3]) }.should_not raise_error(Puppet::ParseError)
  end


  (1..10).each { |n|
    it "should handle #{n} additional arguments" do
      @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
      lambda { @scope.function_fqdn_rand([3,1,2,3,4,5,6,7,8,9,10][0..n]) }.should_not raise_error(Puppet::ParseError)
    end
    it "should handle #{n} additional string arguments" do
      @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
      lambda { @scope.function_fqdn_rand([3,%w{ 1 2 3 4 5 6 7 8 9 10}].flatten[0..n]) }.should_not raise_error(Puppet::ParseError)
    end
  }

  it "should return a value less than max" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    @scope.function_fqdn_rand([3]).should satisfy {|n| n.to_i < 3 }
  end

  it "should return the same values on subsequent invocations for the same host" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1").twice
    @scope.function_fqdn_rand([3,4]).should eql(@scope.function_fqdn_rand([3, 4]))
  end

  it "should return different sequences of value for different hosts" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    val1 = @scope.function_fqdn_rand([10000000,4])
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.2")
    val2 = @scope.function_fqdn_rand([10000000,4])
    val1.should_not eql(val2)
  end

  it "should return different values for the same hosts with different seeds" do
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    val1 = @scope.function_fqdn_rand([10000000,4])
    @scope.expects(:lookupvar).with("::fqdn").returns("127.0.0.1")
    val2 = @scope.function_fqdn_rand([10000000,42])
    val1.should_not eql(val2)
  end
end
