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
    expect(Puppet::Parser::Functions.function("digest")).to eq("function_digest")
  end

  with_digest_algorithms do
    it "should use the proper digest function" do
      result = @scope.function_digest([plaintext])
      expect(result).to(eql( checksum ))
    end

    it "should only accept one parameter" do
      expect do
        @scope.function_digest(['foo', 'bar'])
      end.to raise_error(ArgumentError)
    end
  end
end
