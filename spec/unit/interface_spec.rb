#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')
require 'puppet/interface'

describe Puppet::Interface do
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
    Puppet::Interface.expects(:require).with "puppet/interface/foo"
    Puppet::Interface.interface(:foo)
  end

  it "should be able to load all actions in all search paths"

  describe "#underscorize" do
    faulty = [1, "#foo", "$bar", "sturm und drang", :"sturm und drang"]
    valid  = {
      "Foo"      => :foo,
      :Foo       => :foo,
      "foo_bar"  => :foo_bar,
      :foo_bar   => :foo_bar,
      "foo-bar"  => :foo_bar,
      :"foo-bar" => :foo_bar,
    }

    valid.each do |input, expect|
      it "should map #{input.inspect} to #{expect.inspect}" do
        result = Puppet::Interface.underscorize(input)
        result.should == expect
      end
    end

    faulty.each do |input|
      it "should fail when presented with #{input.inspect} (#{input.class})" do
        expect { Puppet::Interface.underscorize(input) }.
          should raise_error ArgumentError, /not a valid interface name/
      end
    end
  end
end
