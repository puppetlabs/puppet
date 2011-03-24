#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe Puppet::String do
  before :all do
    @strings = Puppet::String::StringCollection.instance_variable_get("@strings").dup
  end

  before :each do
    Puppet::String::StringCollection.instance_variable_get("@strings").clear
  end

  after :all do
    Puppet::String::StringCollection.instance_variable_set("@strings", @strings)
  end

  describe "#define" do
    it "should register the string" do
      string = Puppet::String.define(:string_test_register, '0.0.1')
      string.should == Puppet::String[:string_test_register, '0.0.1']
    end

    it "should load actions" do
      Puppet::String.any_instance.expects(:load_actions)
      Puppet::String.define(:string_test_load_actions, '0.0.1')
    end

    it "should require a version number" do
      proc { Puppet::String.define(:no_version) }.should raise_error(ArgumentError)
    end
  end

  describe "#initialize" do
    it "should require a version number" do
      proc { Puppet::String.new(:no_version) }.should raise_error(ArgumentError)
    end

    it "should require a valid version number" do
      proc { Puppet::String.new(:bad_version, 'Rasins') }.should raise_error(ArgumentError)
    end

    it "should instance-eval any provided block" do
      face = Puppet::String.new(:string_test_block,'0.0.1') do
        action(:something) do
          invoke { "foo" }
        end
      end

      face.something.should == "foo"
    end
  end

  it "should have a name" do
    Puppet::String.new(:me,'0.0.1').name.should == :me
  end

  it "should stringify with its own name" do
    Puppet::String.new(:me,'0.0.1').to_s.should =~ /\bme\b/
  end

  it "should allow overriding of the default format" do
    face = Puppet::String.new(:me,'0.0.1')
    face.set_default_format :foo
    face.default_format.should == :foo
  end

  it "should default to :pson for its format" do
    Puppet::String.new(:me, '0.0.1').default_format.should == :pson
  end

  # Why?
  it "should create a class-level autoloader" do
    Puppet::String.autoloader.should be_instance_of(Puppet::Util::Autoload)
  end

  it "should try to require strings that are not known" do
    Puppet::String::StringCollection.expects(:require).with "puppet/string/foo"
    Puppet::String::StringCollection.expects(:require).with "foo@0.0.1/puppet/string/foo"
    Puppet::String[:foo, '0.0.1']
  end

  it "should be able to load all actions in all search paths"

  describe "with string-level options" do
    it "should support options without arguments" do
      string = Puppet::String.new(:with_options, '0.0.1') do
        option :foo
      end
      string.should be_an_instance_of Puppet::String
      string.should be_option :foo
    end

    it "should support options with an empty block" do
      string = Puppet::String.new(:with_options, '0.0.1') do
        option :foo do
          # this section deliberately left blank
        end
      end
      string.should be_an_instance_of Puppet::String
      string.should be_option :foo
    end

    it "should return all the string-level options" do
      string = Puppet::String.new(:with_options, '0.0.1') do
        option :foo
        option :bar
      end
      string.options.should =~ [:foo, :bar]
    end

    it "should not return any action-level options" do
      string = Puppet::String.new(:with_options, '0.0.1') do
        option :foo
        option :bar
        action :baz do
          option :quux
        end
      end
      string.options.should =~ [:foo, :bar]
    end

    it "should fail when a duplicate option is added" do
      expect {
        Puppet::String.new(:action_level_options, '0.0.1') do
          option :foo
          option :foo
        end
      }.should raise_error ArgumentError, /option foo already defined for/i
    end

    it "should fail when a string option duplicates an action option" do
      expect {
        Puppet::String.new(:action_level_options, '0.0.1') do
          action :bar do option :foo end
          option :foo
        end
      }.should raise_error ArgumentError, /foo already defined on action bar/i
    end

    it "should work when two actions have the same option" do
      string = Puppet::String.new(:with_options, '0.0.1') do
        action :foo do option :quux end
        action :bar do option :quux end
      end

      string.get_action(:foo).options.should =~ [:quux]
      string.get_action(:bar).options.should =~ [:quux]
    end
  end

  describe "with inherited options" do
    let :string do
      parent = Class.new(Puppet::String)
      parent.option(:inherited, :type => :string)
      string = parent.new(:example, '0.2.1')
      string.option(:local)
      string
    end

    describe "#options" do
      it "should list inherited options" do
        string.options.should =~ [:inherited, :local]
      end
    end

    describe "#get_option" do
      it "should return an inherited option object" do
        string.get_option(:inherited).should be_an_instance_of Puppet::String::Option
      end
    end
  end
end
