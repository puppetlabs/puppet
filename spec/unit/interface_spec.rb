#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')
require 'puppet/interface'

describe Puppet::Interface do
  describe "#interface" do
    it "should register the interface" do
      interface = Puppet::Interface.interface(:interface_test_register)
      interface.should == Puppet::Interface.interface(:interface_test_register)
    end

    it "should load actions" do
      Puppet::Interface.any_instance.expects(:load_actions)
      Puppet::Interface.interface(:interface_test_load_actions)
    end

    it "should instance-eval any provided block" do
      face = Puppet::Interface.new(:interface_test_block) do
        action(:something) do
          invoke { "foo" }
        end
      end

      face.something.should == "foo"
    end
  end

  it "should have a name" do
    Puppet::Interface.new(:me).name.should == :me
  end

  it "should stringify with its own name" do
    Puppet::Interface.new(:me).to_s.should =~ /\bme\b/
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

  it "should try to require interfaces that are not known" do
    Puppet::Interface::InterfaceCollection.expects(:require).with "puppet/interface/foo"
    Puppet::Interface.interface(:foo)
  end

  it "should be able to load all actions in all search paths"
end
