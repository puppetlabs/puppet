#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

# This is entirely an internal class for Interface, so we have to load it instead of our class.
require 'puppet/interface'

class ActionManagerTester
  include Puppet::Interface::ActionManager
end

describe Puppet::Interface::ActionManager do
  before do
    @tester = ActionManagerTester.new
  end

  describe "when included in a class" do
    it "should be able to define an action" do
      @tester.action(:foo) { "something "}
    end

    it "should be able to list defined actions" do
      @tester.action(:foo) { "something" }
      @tester.action(:bar) { "something" }

      @tester.actions.should be_include(:bar)
      @tester.actions.should be_include(:foo)
    end

    it "should be able to indicate when an action is defined" do
      @tester.action(:foo) { "something" }
      @tester.should be_action(:foo)
    end
  end

  describe "when used to extend a class" do
    before do
      @tester = Class.new
      @tester.extend(Puppet::Interface::ActionManager)
    end

    it "should be able to define an action" do
      @tester.action(:foo) { "something "}
    end

    it "should be able to list defined actions" do
      @tester.action(:foo) { "something" }
      @tester.action(:bar) { "something" }

      @tester.actions.should be_include(:bar)
      @tester.actions.should be_include(:foo)
    end

    it "should be able to indicate when an action is defined" do
      @tester.action(:foo) { "something" }
      @tester.should be_action(:foo)
    end
  end

  describe "when used both at the class and instance level" do
    before do
      @klass = Class.new do
        include Puppet::Interface::ActionManager
        extend Puppet::Interface::ActionManager
      end
      @instance = @klass.new
    end

    it "should be able to define an action at the class level" do
      @klass.action(:foo) { "something "}
    end

    it "should create an instance method when an action is defined at the class level" do
      @klass.action(:foo) { "something" }
      @instance.foo.should == "something"
    end

    it "should be able to define an action at the instance level" do
      @instance.action(:foo) { "something "}
    end

    it "should create an instance method when an action is defined at the instance level" do
      @instance.action(:foo) { "something" }
      @instance.foo.should == "something"
    end

    it "should be able to list actions defined at the class level" do
      @klass.action(:foo) { "something" }
      @klass.action(:bar) { "something" }

      @klass.actions.should be_include(:bar)
      @klass.actions.should be_include(:foo)
    end

    it "should be able to list actions defined at the instance level" do
      @instance.action(:foo) { "something" }
      @instance.action(:bar) { "something" }

      @instance.actions.should be_include(:bar)
      @instance.actions.should be_include(:foo)
    end

    it "should be able to list actions defined at both instance and class level" do
      @klass.action(:foo) { "something" }
      @instance.action(:bar) { "something" }

      @instance.actions.should be_include(:bar)
      @instance.actions.should be_include(:foo)
    end

    it "should be able to indicate when an action is defined at the class level" do
      @klass.action(:foo) { "something" }
      @instance.should be_action(:foo)
    end

    it "should be able to indicate when an action is defined at the instance level" do
      @klass.action(:foo) { "something" }
      @instance.should be_action(:foo)
    end

    it "should list actions defined in superclasses" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:parent) { "a" }
      @subclass.action(:sub) { "a" }
      @instance.action(:instance) { "a" }

      @instance.should be_action(:parent)
      @instance.should be_action(:sub)
      @instance.should be_action(:instance)
    end

    it "should create an instance method when an action is defined in a superclass" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:foo) { "something" }
      @instance.foo.should == "something"
    end
  end
end
