#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

# This is entirely an internal class for Interface, so we have to load it instead of our class.
require 'puppet/interface'

class ActionManagerTester
  include Puppet::Interface::ActionManager
end

describe Puppet::Interface::ActionManager do
  subject { ActionManagerTester.new }

  describe "when included in a class" do
    it "should be able to define an action" do
      subject.action(:foo) do
        invoke { "something "}
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        invoke { "something" }
      end
      subject.action(:bar) do
        invoke { "something" }
      end

      subject.actions.should include(:bar)
      subject.actions.should include(:foo)
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) do
        invoke { "something" }
      end

      subject.should be_action(:foo)
    end

    it "should correctly treat action names specified as strings" do
      subject.action(:foo) do
        invoke { "something" }
      end

      subject.should be_action("foo")
    end
  end

  describe "when used to extend a class" do
    subject { Class.new.extend(Puppet::Interface::ActionManager) }

    it "should be able to define an action" do
      subject.action(:foo) do
        invoke { "something "}
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        invoke { "something" }
      end
      subject.action(:bar) do
        invoke { "something" }
      end

      subject.actions.should include(:bar)
      subject.actions.should include(:foo)
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) { "something" }
      subject.should be_action(:foo)
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
      @klass.action(:foo) do
        invoke { "something "}
      end
    end

    it "should create an instance method when an action is defined at the class level" do
      @klass.action(:foo) do
        invoke { "something" }
      end
      @instance.foo.should == "something"
    end

    it "should be able to define an action at the instance level" do
      @instance.action(:foo) do
        invoke { "something "}
      end
    end

    it "should create an instance method when an action is defined at the instance level" do
      @instance.action(:foo) do
        invoke { "something" }
      end
      @instance.foo.should == "something"
    end

    it "should be able to list actions defined at the class level" do
      @klass.action(:foo) do
        invoke { "something" }
      end
      @klass.action(:bar) do
        invoke { "something" }
      end

      @klass.actions.should include(:bar)
      @klass.actions.should include(:foo)
    end

    it "should be able to list actions defined at the instance level" do
      @instance.action(:foo) do
        invoke { "something" }
      end
      @instance.action(:bar) do
        invoke { "something" }
      end

      @instance.actions.should include(:bar)
      @instance.actions.should include(:foo)
    end

    it "should be able to list actions defined at both instance and class level" do
      @klass.action(:foo) do
        invoke { "something" }
      end
      @instance.action(:bar) do
        invoke { "something" }
      end

      @instance.actions.should include(:bar)
      @instance.actions.should include(:foo)
    end

    it "should be able to indicate when an action is defined at the class level" do
      @klass.action(:foo) do
        invoke { "something" }
      end
      @instance.should be_action(:foo)
    end

    it "should be able to indicate when an action is defined at the instance level" do
      @klass.action(:foo) do
        invoke { "something" }
      end
      @instance.should be_action(:foo)
    end

    it "should list actions defined in superclasses" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:parent) do
        invoke { "a" }
      end
      @subclass.action(:sub) do
        invoke { "a" }
      end
      @instance.action(:instance) do
        invoke { "a" }
      end

      @instance.should be_action(:parent)
      @instance.should be_action(:sub)
      @instance.should be_action(:instance)
    end

    it "should create an instance method when an action is defined in a superclass" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:foo) do
        invoke { "something" }
      end
      @instance.foo.should == "something"
    end
  end
end
