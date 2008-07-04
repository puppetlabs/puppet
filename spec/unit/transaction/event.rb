#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/event'

describe Puppet::Transaction::Event do
    Event = Puppet::Transaction::Event

    it "should require a name and a source" do
        lambda { Event.new }.should raise_error(ArgumentError)
    end

    it "should have a name getter" do
        Event.new(:foo, "bar").name.should == :foo
    end

    it "should have a source accessor" do
        Event.new(:foo, "bar").source.should == "bar"
    end

    it "should be able to produce a string containing the event name and the source" do
        Event.new(:event, :source).to_s.should == "source -> event"
    end
end
