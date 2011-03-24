#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/string/action_builder'

describe Puppet::String::ActionBuilder do
  describe "::build" do
    it "should build an action" do
      action = Puppet::String::ActionBuilder.build(nil,:foo) do
      end
      action.should be_a(Puppet::String::Action)
      action.name.should == :foo
    end

    it "should define a method on the string which invokes the action" do
      string = Puppet::String.new(:action_builder_test_string, '0.0.1')
      action = Puppet::String::ActionBuilder.build(string, :foo) do
        invoke do
          "invoked the method"
        end
      end

      string.foo.should == "invoked the method"
    end

    it "should require a block" do
      lambda { Puppet::String::ActionBuilder.build(nil,:foo) }.
        should raise_error("Action :foo must specify a block")
    end

    describe "when handling options" do
      let :string do Puppet::String.new(:option_handling, '0.0.1') end

      it "should have a #option DSL function" do
        method = nil
        Puppet::String::ActionBuilder.build(string, :foo) do
          method = self.method(:option)
        end
        method.should be
      end

      it "should define an option without a block" do
        action = Puppet::String::ActionBuilder.build(string, :foo) do
          option :bar
        end
        action.should be_option :bar
      end

      it "should accept an empty block" do
        action = Puppet::String::ActionBuilder.build(string, :foo) do
          option :bar do
            # This space left deliberately blank.
          end
        end
        action.should be_option :bar
      end
    end
  end
end
