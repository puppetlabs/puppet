#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Provider do
  it "should have a specifity class method" do
    Puppet::Provider.should respond_to(:specificity)
  end

  it "should consider two defaults to be higher specificity than one default" do
    one = Class.new(Puppet::Provider)
    one.initvars
    one.defaultfor :operatingsystem => "solaris"

    two = Class.new(Puppet::Provider)
    two.initvars
    two.defaultfor :operatingsystem => "solaris", :operatingsystemrelease => "5.10"

    two.specificity.should > one.specificity
  end

  it "should consider a subclass more specific than its parent class" do
    one = Class.new(Puppet::Provider)
    one.initvars

    two = Class.new(one)
    two.initvars

    two.specificity.should > one.specificity
  end

  it "should be Comparable" do
    res = Puppet::Type.type(:notify).new(:name => "res")

    # Normally I wouldn't like the stubs, but the only way to name a class
    # otherwise is to assign it to a constant, and that hurts more here in
    # testing world. --daniel 2012-01-29
    a = Class.new(Puppet::Provider).new(res)
    a.class.stubs(:name).returns "Puppet::Provider::Notify::A"

    b = Class.new(Puppet::Provider).new(res)
    b.class.stubs(:name).returns "Puppet::Provider::Notify::B"

    c = Class.new(Puppet::Provider).new(res)
    c.class.stubs(:name).returns "Puppet::Provider::Notify::C"

    [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]].each do |this|
      this.sort.should == [a, b, c]
    end

    a.should be < b
    a.should be < c
    b.should be > a
    b.should be < c
    c.should be > a
    c.should be > b

    [a, b, c].each {|x| a.should be <= x }
    [a, b, c].each {|x| c.should be >= x }

    b.should be_between(a, c)
  end
end
