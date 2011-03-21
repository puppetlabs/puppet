#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')
require 'puppet/interface'

describe Puppet::Interface do
  after do
    Puppet::Interface.unload_interface(:me)
  end

  describe "at initialization" do
    it "should require a name" do
      Puppet::Interface.new(:me).name.should == :me
    end

    it "should register itself" do
      Puppet::Interface.expects(:register_interface).with do |name, inst|
        name == :me and inst.is_a?(Puppet::Interface)
      end
      Puppet::Interface.new(:me)
    end

    it "should load actions" do
      Puppet::Interface.any_instance.expects(:load_actions)
      Puppet::Interface.new(:me)
    end

    it "should instance-eval any provided block" do
      face = Puppet::Interface.new(:me) do
        action(:something) { "foo" }
      end

      face.should be_action(:something)
    end
  end

  it "should use its name converted to a string as its string form" do
    Puppet::Interface.new(:me).to_s.should == "me"
  end

  it "should allow overriding of the default format" do
    face = Puppet::Interface.new(:me)
    face.set_default_format :foo
    face.default_format.should == :foo
  end

  it "should default to :pson for its format" do
    Puppet::Interface.new(:me).default_format.should == :pson
  end

  # Why?
  it "should create a class-level autoloader" do
    Puppet::Interface.autoloader.should be_instance_of(Puppet::Util::Autoload)
  end

  it "should set any provided options" do
    Puppet::Interface.new(:me, :verb => "foo").verb.should == "foo"
  end

  it "should create an associated constant when registering an interface" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me) # to remove from the initial registration
    Puppet::Interface.register_interface(:me, face)
    Puppet::Interface::Me.should equal(face)
  end

  # Why is unloading interfaces important?
  it "should be able to unload interfaces" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me)
    Puppet::Interface.const_defined?(:Me).should be_false
  end

  it "should remove the associated constant when an interface is unregistered" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me)
    Puppet::Interface.const_defined?("Me").should be_false
  end

  it "should try to require interfaces that are not known" do
    Puppet::Interface.expects(:require).with "puppet/interface/foo"
    Puppet::Interface.const_get(:Foo)
  end

  it "should not fail when requiring an interface fails" do
    $stderr.stubs(:puts)
    Puppet::Interface.expects(:require).with("puppet/interface/foo").raises LoadError
    lambda { Puppet::Interface::Foo }.should_not raise_error
  end

  it "should be able to load all actions in all search paths"

  describe "#constantize" do
    faulty = [1, "#foo", "$bar", "sturm und drang", :"sturm und drang"]
    valid  = {
      "foo"      => "Foo",
      :foo       => "Foo",
      "foo_bar"  => "FooBar",
      :foo_bar   => "FooBar",
      "foo-bar"  => "FooBar",
      :"foo-bar" => "FooBar",
    }

    valid.each do |input, expect|
      it "should map '#{input}' to '#{expect}'" do
        result = Puppet::Interface.constantize(input)
        result.should be_a String
        result.to_s.should == expect
      end
    end

    faulty.each do |input|
      it "should fail when presented with #{input.inspect} (#{input.class})" do
        expect { Puppet::Interface.constantize(input) }.
          should raise_error ArgumentError, /not a valid interface name/
      end
    end
  end
end
