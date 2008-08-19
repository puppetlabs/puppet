#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/state_machine'

describe Puppet::Util::StateMachine do
    before do
        @class = Puppet::Util::StateMachine
        @machine = @class.new
    end

    it "should instance_eval any provided block" do
        f = @class.new { state(:foo, "foo") }
        f.should be_state(:foo)
    end

    it "should be able to declare states" do
        @machine.should respond_to(:state)
    end

    it "should require documentation when declaring states" do
        lambda { @machine.state(:foo) }.should raise_error(ArgumentError)
    end

    it "should be able to detect when states are set" do
        @machine.state(:foo, "bar")
        @machine.should be_state(:foo)
    end

    it "should be able to declare transitions" do
        @machine.should respond_to(:transition)
    end

    describe "when adding transitions" do
        it "should fail if the starting state of a transition is unknown" do
            @machine.state(:end, "foo")
            lambda { @machine.transition(:start, :end) }.should raise_error(ArgumentError)
        end

        it "should fail if the ending state of a transition is unknown" do
            @machine.state(:start, "foo")
            lambda { @machine.transition(:start, :end) }.should raise_error(ArgumentError)
        end

        it "should fail if an equivalent transition already exists" do
            @machine.state(:start, "foo")
            @machine.state(:end, "foo")
            @machine.transition(:start, :end)
            lambda { @machine.transition(:start, :end) }.should raise_error(ArgumentError)
        end
    end

    describe "when making a transition" do
        it "should require the initial state"

        it "should return all of the transitions to be made"
    end
end
