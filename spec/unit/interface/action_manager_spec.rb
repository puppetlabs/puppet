#!/usr/bin/env rspec
require 'spec_helper'

# This is entirely an internal class for Interface, so we have to load it instead of our class.
require 'puppet/interface'
require 'puppet/face'

class ActionManagerTester
  include Puppet::Interface::ActionManager
end

describe Puppet::Interface::ActionManager do
  subject { ActionManagerTester.new }

  describe "when included in a class" do
    it "should be able to define an action" do
      subject.action(:foo) do
        when_invoked { "something "}
      end
    end

    it "should be able to define a 'script' style action" do
      subject.script :bar do
        "a bar is where beer is found"
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        when_invoked { "something" }
      end
      subject.action(:bar) do
        when_invoked { "something" }
      end

      subject.actions.should =~ [:foo, :bar]
    end

    it "should list 'script' actions" do
      subject.script :foo do "foo" end
      subject.actions.should =~ [:foo]
    end

    it "should list both script and normal actions" do
      subject.action :foo do
        when_invoked do "foo" end
      end
      subject.script :bar do "a bar is where beer is found" end

      subject.actions.should =~ [:foo, :bar]
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) do
        when_invoked { "something" }
      end

      subject.should be_action(:foo)
    end

    it "should indicate an action is defined for script actions" do
      subject.script :foo do "foo" end
      subject.should be_action :foo
    end

    it "should correctly treat action names specified as strings" do
      subject.action(:foo) do
        when_invoked { "something" }
      end

      subject.should be_action("foo")
    end
  end

  describe "when used to extend a class" do
    subject { Class.new.extend(Puppet::Interface::ActionManager) }

    it "should be able to define an action" do
      subject.action(:foo) do
        when_invoked { "something "}
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        when_invoked { "something" }
      end
      subject.action(:bar) do
        when_invoked { "something" }
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
        def __invoke_decorations(*args) true end
        def options() [] end
      end
      @instance = @klass.new
    end

    it "should be able to define an action at the class level" do
      @klass.action(:foo) do
        when_invoked { "something "}
      end
    end

    it "should create an instance method when an action is defined at the class level" do
      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @instance.foo.should == "something"
    end

    it "should be able to define an action at the instance level" do
      @instance.action(:foo) do
        when_invoked { "something "}
      end
    end

    it "should create an instance method when an action is defined at the instance level" do
      @instance.action(:foo) do
        when_invoked { "something" }
      end
      @instance.foo.should == "something"
    end

    it "should be able to list actions defined at the class level" do
      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @klass.action(:bar) do
        when_invoked { "something" }
      end

      @klass.actions.should include(:bar)
      @klass.actions.should include(:foo)
    end

    it "should be able to list actions defined at the instance level" do
      @instance.action(:foo) do
        when_invoked { "something" }
      end
      @instance.action(:bar) do
        when_invoked { "something" }
      end

      @instance.actions.should include(:bar)
      @instance.actions.should include(:foo)
    end

    it "should be able to list actions defined at both instance and class level" do
      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @instance.action(:bar) do
        when_invoked { "something" }
      end

      @instance.actions.should include(:bar)
      @instance.actions.should include(:foo)
    end

    it "should be able to indicate when an action is defined at the class level" do
      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @instance.should be_action(:foo)
    end

    it "should be able to indicate when an action is defined at the instance level" do
      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @instance.should be_action(:foo)
    end

    it "should list actions defined in superclasses" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:parent) do
        when_invoked { "a" }
      end
      @subclass.action(:sub) do
        when_invoked { "a" }
      end
      @instance.action(:instance) do
        when_invoked { "a" }
      end

      @instance.should be_action(:parent)
      @instance.should be_action(:sub)
      @instance.should be_action(:instance)
    end

    it "should create an instance method when an action is defined in a superclass" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:foo) do
        when_invoked { "something" }
      end
      @instance.foo.should == "something"
    end
  end

  describe "#action" do
    it 'should add an action' do
      subject.action(:foo) {  }
      subject.get_action(:foo).should be_a Puppet::Interface::Action
    end

    it 'should support default actions' do
      subject.action(:foo) { default }
      subject.get_default_action.should == subject.get_action(:foo)
    end

    it 'should not support more than one default action' do
      subject.action(:foo) { default }
      expect { subject.action(:bar) { default } }.should raise_error
    end
  end

  describe "#get_action" do
    let :parent_class do
      parent_class = Class.new(Puppet::Interface)
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
