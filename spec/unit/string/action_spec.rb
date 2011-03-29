#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/string/action'

describe Puppet::String::Action do
  describe "when validating the action name" do
    [nil, '', 'foo bar', '-foobar'].each do |input|
      it "should treat #{input.inspect} as an invalid name" do
        expect { Puppet::String::Action.new(nil, input) }.
          should raise_error(/is an invalid action name/)
      end
    end
  end

  describe "when invoking" do
    it "should be able to call other actions on the same object" do
      string = Puppet::String.new(:my_string, '0.0.1') do
        action(:foo) do
          invoke { 25 }
        end

        action(:bar) do
          invoke { "the value of foo is '#{foo}'" }
        end
      end
      string.foo.should == 25
      string.bar.should == "the value of foo is '25'"
    end

    # bar is a class action calling a class action
    # quux is a class action calling an instance action
    # baz is an instance action calling a class action
    # qux is an instance action calling an instance action
    it "should be able to call other actions on the same object when defined on a class" do
      class Puppet::String::MyStringBaseClass < Puppet::String
        action(:foo) do
          invoke { 25 }
        end

        action(:bar) do
          invoke { "the value of foo is '#{foo}'" }
        end

        action(:quux) do
          invoke { "qux told me #{qux}" }
        end
      end

      string = Puppet::String::MyStringBaseClass.new(:my_inherited_string, '0.0.1') do
        action(:baz) do
          invoke { "the value of foo in baz is '#{foo}'" }
        end

        action(:qux) do
          invoke { baz }
        end
      end
      string.foo.should  == 25
      string.bar.should  == "the value of foo is '25'"
      string.quux.should == "qux told me the value of foo in baz is '25'"
      string.baz.should  == "the value of foo in baz is '25'"
      string.qux.should  == "the value of foo in baz is '25'"
    end
  end

  describe "with action-level options" do
    it "should support options with an empty block" do
      string = Puppet::String.new(:action_level_options, '0.0.1') do
        action :foo do
          option "--bar" do
            # this line left deliberately blank
          end
        end
      end

      string.should_not be_option :bar
      string.get_action(:foo).should be_option :bar
    end

    it "should return only action level options when there are no string options" do
      string = Puppet::String.new(:action_level_options, '0.0.1') do
        action :foo do option "--bar" end
      end

      string.get_action(:foo).options.should =~ [:bar]
    end

    describe "with both string and action options" do
      let :string do
        Puppet::String.new(:action_level_options, '0.0.1') do
          action :foo do option "--bar" end
          action :baz do option "--bim" end
          option "--quux"
        end
      end

      it "should return combined string and action options" do
        string.get_action(:foo).options.should =~ [:bar, :quux]
      end

      it "should get an action option when asked" do
        string.get_action(:foo).get_option(:bar).
          should be_an_instance_of Puppet::String::Option
      end

      it "should get a string option when asked" do
        string.get_action(:foo).get_option(:quux).
          should be_an_instance_of Puppet::String::Option
      end

      it "should return options only for this action" do
        string.get_action(:baz).options.should =~ [:bim, :quux]
      end
    end

    it_should_behave_like "things that declare options" do
      def add_options_to(&block)
        string = Puppet::String.new(:with_options, '0.0.1') do
          action(:foo, &block)
        end
        string.get_action(:foo)
      end
    end

    it "should fail when a string option duplicates an action option" do
      expect {
        Puppet::String.new(:action_level_options, '0.0.1') do
          option "--foo"
          action :bar do option "--foo" end
        end
      }.should raise_error ArgumentError, /Option foo conflicts with existing option foo/i
    end
  end
end
