#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/property/list'

list_class = Puppet::Property::List

describe list_class do

  it "should be a subclass of Property" do
    list_class.superclass.must == Puppet::Property
  end

  describe "as an instance" do
    before do
      # Wow that's a messy interface to the resource.
      list_class.initvars
      @resource = stub 'resource', :[]= => nil, :property => nil
      @property = list_class.new(:resource => @resource)
    end

    it "should have a , as default delimiter" do
      @property.delimiter.should == ","
    end

    it "should have a :membership as default membership" do
      @property.membership.should == :membership
    end

    it "should return the same value passed into should_to_s" do
      @property.should_to_s("foo") == "foo"
    end

    it "should return the passed in array values joined with the delimiter from is_to_s" do
      @property.is_to_s(["foo","bar"]).should == "foo,bar"
    end

    it "should be able to correctly convert ':absent' to a string" do
      @property.is_to_s(:absent).should == "absent"
    end

    describe "when adding should to current" do
      it "should add the arrays when current is an array" do
        @property.add_should_with_current(["foo"], ["bar"]).should == ["foo", "bar"]
      end

      it "should return should if current is not a array" do
        @property.add_should_with_current(["foo"], :absent).should == ["foo"]
      end

      it "should return only the uniq elements" do
        @property.add_should_with_current(["foo", "bar"], ["foo", "baz"]).should == ["foo", "bar", "baz"]
      end
    end

    describe "when calling inclusive?" do
      it "should use the membership method to look up on the @resource" do
        @property.expects(:membership).returns(:membership)
        @resource.expects(:[]).with(:membership)
        @property.inclusive?
      end

      it "should return true when @resource[membership] == inclusive" do
        @property.stubs(:membership).returns(:membership)
        @resource.stubs(:[]).with(:membership).returns(:inclusive)
        @property.inclusive?.must == true
      end

      it "should return false when @resource[membership] != inclusive" do
        @property.stubs(:membership).returns(:membership)
        @resource.stubs(:[]).with(:membership).returns(:minimum)
        @property.inclusive?.must == false
      end
    end

    describe "when calling should" do
      it "should return nil if @should is nil" do
        @property.should.must == nil
      end

      it "should return the sorted values of @should as a string if inclusive" do
        @property.should = ["foo", "bar"]
        @property.expects(:inclusive?).returns(true)
        @property.should.must == "bar,foo"
      end

      it "should return the uniq sorted values of @should + retrieve as a string if !inclusive" do
        @property.should = ["foo", "bar"]
        @property.expects(:inclusive?).returns(false)
        @property.expects(:retrieve).returns(["foo","baz"])
        @property.should.must == "bar,baz,foo"
      end
    end

    describe "when calling retrieve" do
      before do
        @provider = mock("provider")
        @property.stubs(:provider).returns(@provider)
      end

      it "should send 'name' to the provider" do
        @provider.expects(:send).with(:group)
        @property.expects(:name).returns(:group)
        @property.retrieve
      end

      it "should return an array with the provider returned info" do
        @provider.stubs(:send).with(:group).returns("foo,bar,baz")
        @property.stubs(:name).returns(:group)
        @property.retrieve == ["foo", "bar", "baz"]
      end

      it "should return :absent when the provider returns :absent" do
        @provider.stubs(:send).with(:group).returns(:absent)
        @property.stubs(:name).returns(:group)
        @property.retrieve == :absent
      end
    end

    describe "when calling safe_insync?" do
      it "should return true unless @should is defined and not nil" do
        @property.must be_safe_insync("foo")
      end

      it "should return true unless the passed in values is not nil" do
        @property.should = "foo"
        @property.must be_safe_insync(nil)
      end

      it "should call prepare_is_for_comparison with value passed in and should" do
        @property.should = "foo"
        @property.expects(:prepare_is_for_comparison).with("bar")
        @property.expects(:should)
        @property.safe_insync?("bar")
      end

      it "should return true if 'is' value is array of comma delimited should values" do
        @property.should = "bar,foo"
        @property.expects(:inclusive?).returns(true)
        @property.must be_safe_insync(["bar","foo"])
      end

      it "should return true if 'is' value is :absent and should value is empty string" do
        @property.should = ""
        @property.expects(:inclusive?).returns(true)
        @property.must be_safe_insync([])
      end

      it "should return false if prepared value != should value" do
        @property.should = "bar,baz,foo"
        @property.expects(:inclusive?).returns(true)
        @property.must_not be_safe_insync(["bar","foo"])
      end
    end

    describe "when calling dearrayify" do
      it "should sort and join the array with 'delimiter'" do
        array = mock "array"
        array.expects(:sort).returns(array)
        array.expects(:join).with(@property.delimiter)
        @property.dearrayify(array)
      end
    end
  end
end
