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
      Puppet::Interface.expects(:register_interface).with { |name, inst| name == :me and inst.is_a?(Puppet::Interface) }
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

  it "should create a class-level autoloader" do
    Puppet::Interface.autoloader.should be_instance_of(Puppet::Util::Autoload)
  end

  it "should define a class-level 'showconfig' action" do
    Puppet::Interface.should be_action(:showconfig)
  end

  it "should set any provided options" do
    Puppet::Interface.new(:me, :verb => "foo").verb.should == "foo"
  end

  it "should be able to register and return interfaces" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me) # to remove from the initial registration
    Puppet::Interface.register_interface(:me, face)
    Puppet::Interface.interface(:me).should equal(face)
  end

  it "should create an associated constant when registering an interface" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me) # to remove from the initial registration
    Puppet::Interface.register_interface(:me, face)
    Puppet::Interface::Me.should equal(face)
  end

  it "should be able to unload interfaces" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me)
    Puppet::Interface.interface(:me).should be_nil
  end

  it "should remove the associated constant when an interface is unregistered" do
    $stderr.stubs(:puts)
    face = Puppet::Interface.new(:me)
    Puppet::Interface.unload_interface(:me)
    lambda { Puppet::Interface.const_get("Me") }.should raise_error(NameError)
  end

  it "should try to require interfaces that are not known" do
    Puppet::Interface.expects(:require).with "puppet/interface/foo"
    Puppet::Interface.interface(:foo)
  end

  it "should not fail when requiring an interface fails" do
    $stderr.stubs(:puts)
    Puppet::Interface.expects(:require).with("puppet/interface/foo").raises LoadError
    lambda { Puppet::Interface.interface(:foo) }.should_not raise_error
  end

  it "should be able to load all actions in all search paths"
end
