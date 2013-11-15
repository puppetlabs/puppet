#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::Resource::Param do
  it "can be instantiated" do
    Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => 'foo')
  end

  it "stores the source file" do
    param = Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => 'foo', :file => 'foo.pp')
    param.file.should == 'foo.pp'
  end

  it "stores the line number" do
    param = Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => 'foo', :line => 42)
    param.line.should == 42
  end

  context "parameter validation" do
    it "throws an error when instantiated without a name" do
      expect {
        Puppet::Parser::Resource::Param.new(:value => 'foo')
      }.to raise_error(Puppet::Error, /name is a required option/)
    end

    it "throws an error when instantiated without a value" do
      expect {
        Puppet::Parser::Resource::Param.new(:name => 'myparam')
      }.to raise_error(Puppet::Error, /value is a required option/)
    end

    it "throws an error when instantiated with a nil value" do
      expect {
        Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => nil)
      }.to raise_error(Puppet::Error, /value is a required option/)
    end

    it "includes file/line context in errors" do
      expect {
        Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => nil, :file => 'foo.pp', :line => 42)
      }.to raise_error(Puppet::Error, /foo.pp:42/)
    end
  end
end
