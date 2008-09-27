#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/property'

describe Puppet::Property do
    describe "when setting the value" do
        it "should just set the 'should' value" do
            @class = Class.new(Puppet::Property)
            @class.initvars
            @property = @class.new :resource => mock('resource')

            @property.expects(:should=).with("foo")
            @property.value = "foo"
        end
    end

    describe "when returning the value" do
        before do
            @class = Class.new(Puppet::Property)
            @class.initvars
            @property = @class.new :resource => mock('resource')
        end

        it "should return nil if no value is set" do
            @property.value.should be_nil
        end

        it "should return any set 'should' value" do
            @property.should = "foo"
            @property.value.should == "foo"
        end
    end
end
