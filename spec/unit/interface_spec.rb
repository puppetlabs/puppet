#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe Puppet::Interface do
  before :all do
    @interfaces = Puppet::Interface::InterfaceCollection.instance_variable_get("@interfaces").dup
  end

  before :each do
    Puppet::Interface::InterfaceCollection.instance_variable_get("@interfaces").clear
  end

  after :all do
    Puppet::Interface::InterfaceCollection.instance_variable_set("@interfaces", @interfaces)
  end

  describe "#interface" do
    it "should register the interface" do
      interface = Puppet::Interface.interface(:interface_test_register, '0.0.1')
      interface.should == Puppet::Interface.interface(:interface_test_register, '0.0.1')
    end

    it "should load actions" do
      Puppet::Interface.any_instance.expects(:load_actions)
      Puppet::Interface.interface(:interface_test_load_actions, '0.0.1')
    end

    it "should require a version number" do
      proc { Puppet::Interface.interface(:no_version) }.should raise_error(ArgumentError)
    end
  end

  describe "#initialize" do
    it "should require a version number" do
      proc { Puppet::Interface.new(:no_version) }.should raise_error(/declared without version/)
    end

    it "should instance-eval any provided block" do
      face = Puppet::Interface.new(:interface_test_block, :version => '0.0.1') do
        action(:something) do
          invoke { "foo" }
        end
      end

      face.something.should == "foo"
    end
  end

  it "should have a name" do
    Puppet::Interface.new(:me, :version => '0.0.1').name.should == :me
  end

  it "should stringify with its own name" do
    Puppet::Interface.new(:me, :version => '0.0.1').to_s.should =~ /\bme\b/
  end

  it "should allow overriding of the default format" do
    face = Puppet::Interface.new(:me, :version => '0.0.1')
    face.set_default_format :foo
    face.default_format.should == :foo
  end

  it "should default to :pson for its format" do
    Puppet::Interface.new(:me, :version => '0.0.1').default_format.should == :pson
  end

  # Why?
  it "should create a class-level autoloader" do
    Puppet::Interface.autoloader.should be_instance_of(Puppet::Util::Autoload)
  end

  it "should set any provided options" do
    Puppet::Interface.new(:me, :version => 1, :verb => "foo").verb.should == "foo"
  end

  it "should try to require interfaces that are not known" do
    Puppet::Interface::InterfaceCollection.expects(:require).with "puppet/interface/v0.0.1/foo"
    Puppet::Interface.interface(:foo, '0.0.1')
  end

  it "should be able to load all actions in all search paths"
end
