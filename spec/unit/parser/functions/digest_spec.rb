#!/usr/bin/env rspec
require 'spec_helper'

describe "the digest function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("digest").should == "function_digest"
  end

  it "should perform an MD5 digest when the digest_algorithm is not set" do
    Puppet[:digest_algorithm] = nil
    result = @scope.function_digest(['foo'])
    result.should(eql( "acbd18db4cc2f85cedef654fccc4a4d8" ))
  end

  it "should perform an MD5 digest when the digest_algorithm is set to md5" do
    Puppet[:digest_algorithm] = 'md5'
    result = @scope.function_digest(['foo'])
    result.should(eql( "acbd18db4cc2f85cedef654fccc4a4d8" ))
  end

  it "should perform an SHA256 digest when the digest_algorithm is set to sha256" do
    Puppet[:digest_algorithm] = 'sha256'
    result = @scope.function_digest(['foo'])
    result.should(eql( "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae" ))
  end

  it "should ignore all parameters but the first" do
    Puppet[:digest_algorithm] = nil
    result1 = @scope.function_digest(['foo'])
    result2 = @scope.function_digest(['foo', 'bar'])
    result1.should == result2
  end

end
