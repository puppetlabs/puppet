#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/action_builder'

describe Puppet::Interface::ActionBuilder do
  describe "::build" do
    it "should build an action" do
      action = Puppet::Interface::ActionBuilder.build(nil,:foo) do
      end
      action.should be_a(Puppet::Interface::Action)
      action.name.should == "foo"
    end

    it "should define a method on the interface which invokes the action" do
      interface = Puppet::Interface.new(:action_builder_test_interface)
      action = Puppet::Interface::ActionBuilder.build(interface, :foo) do
        invoke do
          "invoked the method"
        end
      end

      interface.foo.should == "invoked the method"
    end

    it "should require a block" do
      lambda { Puppet::Interface::ActionBuilder.build(nil,:foo) }.should raise_error("Action 'foo' must specify a block")
    end
  end
end
