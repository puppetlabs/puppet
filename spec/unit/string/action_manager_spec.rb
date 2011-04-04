#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

# This is entirely an internal class for String, so we have to load it instead of our class.
require 'puppet/string'

class ActionManagerTester
  include Puppet::String::ActionManager
end

describe Puppet::String::ActionManager do
  subject { ActionManagerTester.new }

  describe "when included in a class" do
    it "should be able to define an action" do
      subject.action(:foo) do
        invoke { "something "}
      end
    end

    it "should be able to define a 'script' style action" do
      subject.script :bar do
        "a bar is where beer is found"
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        invoke { "something" }
      end
      subject.action(:bar) do
        invoke { "something" }
      end

      subject.actions.should =~ [:foo, :bar]
    end

    it "should list 'script' actions" do
      subject.script :foo do "foo" end
      subject.actions.should =~ [:foo]
    end

    it "should list both script and normal actions" do
      subject.action :foo do
        invoke do "foo" end
      end
      subject.script :bar do "a bar is where beer is found" end

      subject.actions.should =~ [:foo, :bar]
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) do
        invoke { "something" }
      end

      subject.should be_action(:foo)
    end

    it "should indicate an action is defined for script actions" do
      subject.script :foo do "foo" end
      subject.should be_action :foo
    end

    it "should correctly treat action names specified as strings" do
      subject.action(:foo) do
        invoke { "something" }
      end

      subject.should be_action("foo")
    end
  end

  describe "when used to extend a class" do
    subject { Class.new.extend(Puppet::String::ActionManager) }

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
        include Puppet::String::ActionManager
        extend Puppet::String::ActionManager
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

  describe "#get_action" do
    let :parent_class do
      parent_class = Class.new(Puppet::String)
      parent_class.action(:foo) {}
      parent_class
    end

    it "should check that we can find inherited actions when we are a class" do
      Class.new(parent_class).get_action(:foo).name.should == :foo
    end

    it "should check that we can find inherited actions when we are an instance" do
      instance = parent_class.new(:foo, '0.0.0')
      instance.get_action(:foo).name.should == :foo
    end
  end
end
