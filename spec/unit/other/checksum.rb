#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/checksum'

describe Puppet::Checksum do
    it "should have 'Checksum' and the checksum algorithm when converted to a string" do
        sum = Puppet::Checksum.new("whatever")
        sum.algorithm = "yay"
        sum.to_s.should == "Checksum<{yay}whatever>"
    end

    it "should convert algorithm names to symbols when they are set after checksum creation" do
        sum = Puppet::Checksum.new("whatever")
        sum.algorithm = "yay"
        sum.algorithm.should == :yay
    end
end

describe Puppet::Checksum, " when initializing" do
    it "should require a name" do
        proc { Puppet::Checksum.new(nil) }.should raise_error(ArgumentError)
    end

    it "should set the name appropriately" do
        Puppet::Checksum.new("whatever").name.should == "whatever"
    end

    it "should parse checksum algorithms out of the name if they are there" do
        sum = Puppet::Checksum.new("{other}whatever")
        sum.algorithm.should == :other
        sum.name.should == "whatever"
    end

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
        Puppet::Checksum.new("whatever").algorithm.should == :md5
    end
end

describe Puppet::Checksum, " when using back-ends" do
    it "should redirect using Puppet::Indirector" do
        Puppet::Indirector::Indirection.instance(:checksum).model.should equal(Puppet::Checksum)
    end

    it "should have a :save instance method" do
        Puppet::Checksum.new("mysum").should respond_to(:save)
    end

    it "should respond to :find" do
        Puppet::Checksum.should respond_to(:find)
    end

    it "should respond to :destroy" do
        Puppet::Checksum.should respond_to(:destroy)
    end
end
