#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/interface'

class ActionManagerTester
  include Puppet::Interface::ActionManager
end

describe Puppet::Interface::ActionManager do
  subject { ActionManagerTester.new }

  describe "when included in a class" do
    it "should be able to define an action" do
      subject.action(:foo) do
        when_invoked { |options| "something "}
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        when_invoked { |options| "something" }
      end
      subject.action(:bar) do
        when_invoked { |options| "something" }
      end

      expect(subject.actions).to match_array([:foo, :bar])
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) do
        when_invoked { |options| "something" }
      end

      expect(subject).to be_action(:foo)
    end

    it "should correctly treat action names specified as strings" do
      subject.action(:foo) do
        when_invoked { |options| "something" }
      end

      expect(subject).to be_action("foo")
    end
  end

  describe "when used to extend a class" do
    subject { Class.new.extend(Puppet::Interface::ActionManager) }

    it "should be able to define an action" do
      subject.action(:foo) do
        when_invoked { |options| "something "}
      end
    end

    it "should be able to list defined actions" do
      subject.action(:foo) do
        when_invoked { |options| "something" }
      end
      subject.action(:bar) do
        when_invoked { |options| "something" }
      end

      expect(subject.actions).to include(:bar)
      expect(subject.actions).to include(:foo)
    end

    it "should be able to indicate when an action is defined" do
      subject.action(:foo) { when_invoked do |options| true end }
      expect(subject).to be_action(:foo)
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
        when_invoked { |options| "something "}
      end
    end

    it "should create an instance method when an action is defined at the class level" do
      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      expect(@instance.foo).to eq("something")
    end

    it "should be able to define an action at the instance level" do
      @instance.action(:foo) do
        when_invoked { |options| "something "}
      end
    end

    it "should create an instance method when an action is defined at the instance level" do
      @instance.action(:foo) do
        when_invoked { |options| "something" }
      end
      expect(@instance.foo).to eq("something")
    end

    it "should be able to list actions defined at the class level" do
      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      @klass.action(:bar) do
        when_invoked { |options| "something" }
      end

      expect(@klass.actions).to include(:bar)
      expect(@klass.actions).to include(:foo)
    end

    it "should be able to list actions defined at the instance level" do
      @instance.action(:foo) do
        when_invoked { |options| "something" }
      end
      @instance.action(:bar) do
        when_invoked { |options| "something" }
      end

      expect(@instance.actions).to include(:bar)
      expect(@instance.actions).to include(:foo)
    end

    it "should be able to list actions defined at both instance and class level" do
      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      @instance.action(:bar) do
        when_invoked { |options| "something" }
      end

      expect(@instance.actions).to include(:bar)
      expect(@instance.actions).to include(:foo)
    end

    it "should be able to indicate when an action is defined at the class level" do
      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      expect(@instance).to be_action(:foo)
    end

    it "should be able to indicate when an action is defined at the instance level" do
      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      expect(@instance).to be_action(:foo)
    end

    context "with actions defined in superclass" do
      before :each do
        @subclass = Class.new(@klass)
        @instance = @subclass.new

        @klass.action(:parent) do
          when_invoked { |options| "a" }
        end
        @subclass.action(:sub) do
          when_invoked { |options| "a" }
        end
        @instance.action(:instance) do
          when_invoked { |options| "a" }
        end
      end

      it "should list actions defined in superclasses" do
        expect(@instance).to be_action(:parent)
        expect(@instance).to be_action(:sub)
        expect(@instance).to be_action(:instance)
      end

      it "should list inherited actions" do
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
      end

      it "should not duplicate instance actions after fetching them (#7699)" do
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
        @instance.get_action(:instance)
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
      end

      it "should not duplicate subclass actions after fetching them (#7699)" do
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
        @instance.get_action(:sub)
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
      end

      it "should not duplicate superclass actions after fetching them (#7699)" do
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
        @instance.get_action(:parent)
        expect(@instance.actions).to match_array([:instance, :parent, :sub])
      end
    end

    it "should create an instance method when an action is defined in a superclass" do
      @subclass = Class.new(@klass)
      @instance = @subclass.new

      @klass.action(:foo) do
        when_invoked { |options| "something" }
      end
      expect(@instance.foo).to eq("something")
    end
  end

  describe "#action" do
    it 'should add an action' do
      subject.action(:foo) { when_invoked do |options| true end }
      expect(subject.get_action(:foo)).to be_a Puppet::Interface::Action
    end

    it 'should support default actions' do
      subject.action(:foo) { when_invoked do |options| true end; default }
      expect(subject.get_default_action).to eq(subject.get_action(:foo))
    end

    it 'should not support more than one default action' do
      subject.action(:foo) { when_invoked do |options| true end; default }
      expect { subject.action(:bar) {
          when_invoked do |options| true end
          default
        }
      }.to raise_error /cannot both be default/
    end
  end

  describe "#get_action" do
    let :parent_class do
      parent_class = Class.new(Puppet::Interface)
      parent_class.action(:foo) { when_invoked do |options| true end }
      parent_class
    end

    it "should check that we can find inherited actions when we are a class" do
      expect(Class.new(parent_class).get_action(:foo).name).to eq(:foo)
    end

    it "should check that we can find inherited actions when we are an instance" do
      instance = parent_class.new(:foo, '0.0.0')
      expect(instance.get_action(:foo).name).to eq(:foo)
    end
  end
end
