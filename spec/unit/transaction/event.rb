#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/event'

describe Puppet::Transaction::Event do
    [:log, :previous_value, :desired_value, :property, :resource, :name, :result].each do |attr|
        it "should support #{attr}" do
            event = Puppet::Transaction::Event.new
            event.send(attr.to_s + "=", "foo")
            event.send(attr).should == "foo"
        end
    end

    it "should produce the log when converted to a string" do
        event = Puppet::Transaction::Event.new
        event.expects(:log).returns "my log"
        event.to_s.should == "my log"
    end
end
