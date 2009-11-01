#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/event'

describe Puppet::Transaction::Event do
    [:log, :previous_value, :desired_value, :property, :resource, :name, :log, :node, :version, :file, :line, :tags].each do |attr|
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

    it "should support 'status'" do
        event = Puppet::Transaction::Event.new
        event.status = "success"
        event.status.should == "success"
    end

    it "should fail if the status is not to 'noop', 'success', or 'failure" do
        event = Puppet::Transaction::Event.new
        lambda { event.status = "foo" }.should raise_error(ArgumentError)
    end

    it "should support tags" do
        Puppet::Transaction::Event.ancestors.should include(Puppet::Util::Tagging)
    end

    it "should be able to send logs"

    it "should create a timestamp at its creation time" do
        Puppet::Transaction::Event.new.time.should be_instance_of(Time)
    end
end
