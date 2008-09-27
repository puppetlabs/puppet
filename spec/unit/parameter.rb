#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter do
    describe "when returning the value" do
        before do
            @class = Class.new(Puppet::Parameter)
            @class.initvars
            @parameter = @class.new :resource => mock('resource')
        end

        it "should return nil if no value is set" do
            @parameter.value.should be_nil
        end

        it "should return any set value" do
            @parameter.value = "foo"
            @parameter.value.should == "foo"
        end
    end
end
