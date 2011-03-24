#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe Puppet::Interface::InterfaceCollection do
  before :all do
    @interfaces = subject.instance_variable_get("@interfaces").dup
  end

  before :each do
    subject.instance_variable_get("@interfaces").clear
  end

  after :all do
    subject.instance_variable_set("@interfaces", @interfaces)
  end

  describe "::interfaces" do
  end

  describe "::[]" do
    before :each do
      subject.instance_variable_get("@interfaces")[:foo]['0.0.1'] = 10
    end

    it "should return the interface with the given name" do
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to load the interface if it isn't found" do
      subject.expects(:require).with('puppet/interface/v0.0.1/bar')
      subject["bar", '0.0.1']
    end
  end

  describe "::interface?" do
    before :each do
      subject.instance_variable_get("@interfaces")[:foo]['0.0.1'] = 10
    end

    it "should return true if the interface specified is registered" do
      subject.interface?("foo", '0.0.1').should == true
    end

    it "should attempt to require the interface if it is not registered" do
      subject.expects(:require).with('puppet/interface/v0.0.1/bar')
      subject.interface?("bar", '0.0.1')
    end

    it "should return true if requiring the interface registered it" do
      subject.stubs(:require).with do
        subject.instance_variable_get("@interfaces")[:bar]['0.0.1'] = 20
      end
      subject.interface?("bar", '0.0.1').should == true
    end

    it "should return false if the interface is not registered" do
      subject.stubs(:require).returns(true)
      subject.interface?("bar", '0.0.1').should == false
    end

    it "should return false if there is a LoadError requiring the interface" do
      subject.stubs(:require).raises(LoadError)
      subject.interface?("bar", '0.0.1').should == false
    end
  end

  describe "::register" do
    it "should store the interface by name" do
      interface = Puppet::Interface.new(:my_interface, '0.0.1')
      subject.register(interface)
      subject.instance_variable_get("@interfaces").should == {:my_interface => {'0.0.1' => interface}}
    end
  end

  describe "::underscorize" do
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
        result = subject.underscorize(input)
        result.should == expect
      end
    end

    faulty.each do |input|
      it "should fail when presented with #{input.inspect} (#{input.class})" do
        expect { subject.underscorize(input) }.
          should raise_error ArgumentError, /not a valid interface name/
      end
    end
  end
end
