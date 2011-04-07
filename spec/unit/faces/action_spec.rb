#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/faces/action'

describe Puppet::Faces::Action do
  describe "when validating the action name" do
    [nil, '', 'foo bar', '-foobar'].each do |input|
      it "should treat #{input.inspect} as an invalid name" do
        expect { Puppet::Faces::Action.new(nil, input) }.
          should raise_error(/is an invalid action name/)
      end
    end
  end

  describe "when invoking" do
    it "should be able to call other actions on the same object" do
      face = Puppet::Faces.new(:my_face, '0.0.1') do
        action(:foo) do
          when_invoked { 25 }
        end

        action(:bar) do
          when_invoked { "the value of foo is '#{foo}'" }
        end
      end
      face.foo.should == 25
      face.bar.should == "the value of foo is '25'"
    end

    # bar is a class action calling a class action
    # quux is a class action calling an instance action
    # baz is an instance action calling a class action
    # qux is an instance action calling an instance action
    it "should be able to call other actions on the same object when defined on a class" do
      class Puppet::Faces::MyFacesBaseClass < Puppet::Faces
        action(:foo) do
          when_invoked { 25 }
        end

        action(:bar) do
          when_invoked { "the value of foo is '#{foo}'" }
        end

        action(:quux) do
          when_invoked { "qux told me #{qux}" }
        end
      end

      face = Puppet::Faces::MyFacesBaseClass.new(:my_inherited_face, '0.0.1') do
        action(:baz) do
          when_invoked { "the value of foo in baz is '#{foo}'" }
        end

        action(:qux) do
          when_invoked { baz }
        end
      end
      face.foo.should  == 25
      face.bar.should  == "the value of foo is '25'"
      face.quux.should == "qux told me the value of foo in baz is '25'"
      face.baz.should  == "the value of foo in baz is '25'"
      face.qux.should  == "the value of foo in baz is '25'"
    end

    context "when calling the Ruby API" do
      let :face do
        Puppet::Faces.new(:ruby_api, '1.0.0') do
          action :bar do
            when_invoked do |options|
              options
            end
          end
        end
      end

      it "should work when no options are supplied" do
        options = face.bar
        options.should == {}
      end

      it "should work when options are supplied" do
        options = face.bar :bar => "beer"
        options.should == { :bar => "beer" }
      end
    end
  end

  describe "with action-level options" do
    it "should support options with an empty block" do
      face = Puppet::Faces.new(:action_level_options, '0.0.1') do
        action :foo do
          option "--bar" do
            # this line left deliberately blank
          end
        end
      end

      face.should_not be_option :bar
      face.get_action(:foo).should be_option :bar
    end

    it "should return only action level options when there are no face options" do
      face = Puppet::Faces.new(:action_level_options, '0.0.1') do
        action :foo do option "--bar" end
      end

      face.get_action(:foo).options.should =~ [:bar]
    end

    describe "with both face and action options" do
      let :face do
        Puppet::Faces.new(:action_level_options, '0.0.1') do
          action :foo do option "--bar" end
          action :baz do option "--bim" end
          option "--quux"
        end
      end

      it "should return combined face and action options" do
        face.get_action(:foo).options.should =~ [:bar, :quux]
      end

      it "should fetch options that the face inherited" do
        parent = Class.new(Puppet::Faces)
        parent.option "--foo"
        child = parent.new(:inherited_options, '0.0.1') do
          option "--bar"
          action :action do option "--baz" end
        end

        action = child.get_action(:action)
        action.should be

        [:baz, :bar, :foo].each do |name|
          action.get_option(name).should be_an_instance_of Puppet::Faces::Option
        end
      end

      it "should get an action option when asked" do
        face.get_action(:foo).get_option(:bar).
          should be_an_instance_of Puppet::Faces::Option
      end

      it "should get a face option when asked" do
        face.get_action(:foo).get_option(:quux).
          should be_an_instance_of Puppet::Faces::Option
      end

      it "should return options only for this action" do
        face.get_action(:baz).options.should =~ [:bim, :quux]
      end
    end

    it_should_behave_like "things that declare options" do
      def add_options_to(&block)
        face = Puppet::Faces.new(:with_options, '0.0.1') do
          action(:foo, &block)
        end
        face.get_action(:foo)
      end
    end

    it "should fail when a face option duplicates an action option" do
      expect {
        Puppet::Faces.new(:action_level_options, '0.0.1') do
          option "--foo"
          action :bar do option "--foo" end
        end
      }.should raise_error ArgumentError, /Option foo conflicts with existing option foo/i
    end
  end
end
