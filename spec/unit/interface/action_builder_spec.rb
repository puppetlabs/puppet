#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/action_builder'

describe Puppet::Interface::ActionBuilder do
  describe "::build" do
    it "should build an action" do
      action = Puppet::Interface::ActionBuilder.build(nil, :foo) do
      end
      action.should be_a(Puppet::Interface::Action)
      action.name.should == :foo
    end

    it "should define a method on the face which invokes the action" do
      face = Puppet::Interface.new(:action_builder_test_interface, '0.0.1')
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do
          "invoked the method"
        end
      end

      face.foo.should == "invoked the method"
    end

    it "should require a block" do
      expect { Puppet::Interface::ActionBuilder.build(nil, :foo) }.
        should raise_error("Action :foo must specify a block")
    end

    describe "when handling options" do
      let :face do Puppet::Interface.new(:option_handling, '0.0.1') end

      it "should have a #option DSL function" do
        method = nil
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          method = self.method(:option)
        end
        method.should be
      end

      it "should define an option without a block" do
        action = Puppet::Interface::ActionBuilder.build(face, :foo) do
          option "--bar"
        end
        action.should be_option :bar
      end

      it "should accept an empty block" do
        action = Puppet::Interface::ActionBuilder.build(face, :foo) do
          option "--bar" do
            # This space left deliberately blank.
          end
        end
        action.should be_option :bar
      end
    end
  end
end
