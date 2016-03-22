#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/ldap/generator'

describe Puppet::Util::Ldap::Generator do
  before do
    @generator = Puppet::Util::Ldap::Generator.new(:uno)
  end

  it "should require a parameter name at initialization" do
    lambda { Puppet::Util::Ldap::Generator.new }.should raise_error
  end

  it "should always return its name as a string" do
    g = Puppet::Util::Ldap::Generator.new(:myname)
    g.name.should == "myname"
  end

  it "should provide a method for declaring the source parameter" do
    @generator.from(:dos)
  end

  it "should always return a set source as a string" do
    @generator.from(:dos)
    @generator.source.should == "dos"
  end

  it "should return the source as nil if there is no source" do
    @generator.source.should be_nil
  end

  it "should return itself when declaring the source" do
    @generator.from(:dos).should equal(@generator)
  end

  it "should run the provided block when asked to generate the value" do
    @generator.with { "yayness" }
    @generator.generate.should == "yayness"
  end

  it "should pass in any provided value to the block" do
    @generator.with { |value| value.upcase }
    @generator.generate("myval").should == "MYVAL"
  end

  it "should return itself when declaring the code used for generating" do
    @generator.with { |value| value.upcase }.should equal(@generator)
  end
end
