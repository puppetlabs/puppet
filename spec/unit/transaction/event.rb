#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/event'

describe Puppet::Transaction::Event do
    Event = Puppet::Transaction::Event

    it "should have an event accessor" do
        event = Event.new :event => :foo, :source => "foo"
        event.event.should == :foo
    end

    it "should have a source accessor" do
        event = Event.new :event => :foo, :source => "foo"
        event.source.should == "foo"
    end

    it "should have a transaction accessor" do
        event = Event.new :event => :foo, :source => "foo"
        event.transaction = "eh"
        event.transaction.should == "eh"
    end

    it "should require a source" do
        lambda { Event.new :event => :foo }.should raise_error
    end

    it "should require an event" do
        lambda { Event.new :source => "eh" }.should raise_error
    end

    it "should be able to produce a string containing the event name and the source" do
        Event.new(:event => :event, :source => :source).to_s.should == "source -> event"
    end
end
