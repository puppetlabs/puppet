#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/property/keyvalue'

klass = Puppet::Property::KeyValue

describe klass do

  it "should be a subclass of Property" do
    klass.superclass.must == Puppet::Property
  end

  describe "as an instance" do
    before do
      # Wow that's a messy interface to the resource.
      klass.initvars
      @resource = stub 'resource', :[]= => nil, :property => nil
      @property = klass.new(:resource => @resource)
    end

    it "should have a , as default delimiter" do
      @property.delimiter.should == ";"
    end

    it "should have a = as default separator" do
      @property.separator.should == "="
    end

    it "should have a :membership as default membership" do
      @property.membership.should == :key_value_membership
    end

    it "should return the same value passed into should_to_s" do
      @property.should_to_s({:foo => "baz", :bar => "boo"}) == "foo=baz;bar=boo"
    end

    it "should return the passed in hash values joined with the delimiter from is_to_s" do
      s = @property.is_to_s({"foo" => "baz" , "bar" => "boo"})

      # We can't predict the order the hash is processed in...
      ["foo=baz;bar=boo", "bar=boo;foo=baz"].should be_include s
    end

    describe "when calling inclusive?" do
      it "should use the membership method to look up on the @resource" do
        @property.expects(:membership).returns(:key_value_membership)
        @resource.expects(:[]).with(:key_value_membership)
        @property.inclusive?
      end

      it "should return true when @resource[membership] == inclusive" do
        @property.stubs(:membership).returns(:key_value_membership)
        @resource.stubs(:[]).with(:key_value_membership).returns(:inclusive)
        @property.inclusive?.must == true
      end

      it "should return false when @resource[membership] != inclusive" do
        @property.stubs(:membership).returns(:key_value_membership)
        @resource.stubs(:[]).with(:key_value_membership).returns(:minimum)
        @property.inclusive?.must == false
      end
    end

    describe "when calling process_current_hash" do
      it "should return {} if hash is :absent" do
        @property.process_current_hash(:absent).must == {}
      end

      it "should set every key to nil if inclusive?" do
        @property.stubs(:inclusive?).returns(true)
        @property.process_current_hash({:foo => "bar", :do => "re"}).must == { :foo => nil, :do => nil }
      end

      it "should return the hash if !inclusive?" do
        @property.stubs(:inclusive?).returns(false)
        @property.process_current_hash({:foo => "bar", :do => "re"}).must == {:foo => "bar", :do => "re"}
      end
    end

    describe "when calling should" do
      it "should return nil if @should is nil" do
        @property.should.must == nil
      end

      it "should call process_current_hash" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.stubs(:retrieve).returns({:do => "re", :mi => "fa" })
        @property.expects(:process_current_hash).returns({})
        @property.should
      end

      it "should return the hashed values of @should and the nilled values of retrieve if inclusive" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:retrieve).returns({:do => "re", :mi => "fa" })
        @property.expects(:inclusive?).returns(true)
        @property.should.must == { :foo => "baz", :bar => "boo", :do => nil, :mi => nil }
      end

      it "should return the hashed @should + the unique values of retrieve if !inclusive" do
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:retrieve).returns({:foo => "diff", :do => "re", :mi => "fa"})
        @property.expects(:inclusive?).returns(false)
        @property.should.must == { :foo => "baz", :bar => "boo", :do => "re", :mi => "fa" }
      end
    end

    describe "when calling retrieve" do
      before do
        @provider = mock("provider")
        @property.stubs(:provider).returns(@provider)
      end

      it "should send 'name' to the provider" do
        @provider.expects(:send).with(:keys)
        @property.expects(:name).returns(:keys)
        @property.retrieve
      end

      it "should return a hash with the provider returned info" do
        @provider.stubs(:send).with(:keys).returns({"do" => "re", "mi" => "fa" })
        @property.stubs(:name).returns(:keys)
        @property.retrieve == {"do" => "re", "mi" => "fa" }
      end

      it "should return :absent when the provider returns :absent" do
        @provider.stubs(:send).with(:keys).returns(:absent)
        @property.stubs(:name).returns(:keys)
        @property.retrieve == :absent
      end
    end

    describe "when calling hashify" do
      it "should return the array hashified" do
        @property.hashify(["foo=baz", "bar=boo"]).must == { :foo => "baz", :bar => "boo" }
      end
    end

    describe "when calling safe_insync?" do
      before do
        @provider = mock("provider")
        @property.stubs(:provider).returns(@provider)
        @property.stubs(:name).returns(:prop_name)
      end

      it "should return true unless @should is defined and not nil" do
        @property.safe_insync?("foo") == true
      end

      it "should return true if the passed in values is nil" do
        @property.should = "foo"
        @property.safe_insync?(nil) == true
      end

      it "should return true if hashified should value == (retrieved) value passed in" do
        @provider.stubs(:prop_name).returns({ :foo => "baz", :bar => "boo" })
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:inclusive?).returns(true)
        @property.safe_insync?({ :foo => "baz", :bar => "boo" }).must == true
      end

      it "should return false if prepared value != should value" do
        @provider.stubs(:prop_name).returns({ "foo" => "bee", "bar" => "boo" })
        @property.should = ["foo=baz", "bar=boo"]
        @property.expects(:inclusive?).returns(true)
        @property.safe_insync?({ "foo" => "bee", "bar" => "boo" }).must == false
      end
    end
  end
end
