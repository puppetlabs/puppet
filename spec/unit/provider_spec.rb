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
end
