#!/usr/bin/env rspec
require 'spec_helper'

describe "the digest function", :uses_checksums => true do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    n = Puppet::Node.new('unnamed')
    c = Puppet::Parser::Compiler.new(n)
    @scope = Puppet::Parser::Scope.new(c)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("digest").should == "function_digest"
  end

  with_digest_algorithms do
    it "should use the proper digest function" do
      result = @scope.function_digest([plaintext])
      result.should(eql( checksum ))
    end

    it "should ignore all parameters but the first" do
      result1 = @scope.function_digest(['foo'])
      result2 = @scope.function_digest(['foo', 'bar'])
      result1.should == result2
    end
  end
end
