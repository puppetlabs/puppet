#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/rails/reference_serializer'

class SerializeTester
  include Puppet::Util::ReferenceSerializer
end

describe Puppet::Util::ReferenceSerializer do
  before do
    @tester = SerializeTester.new
  end

  describe "when serializing" do
    it "should yaml-dump resource references" do
      ref = Puppet::Resource.new("file", "/foo")
      @tester.serialize_value(ref).should =~ /^---/
    end

    it "should convert the boolean 'true' into the string 'true'" do
      @tester.serialize_value(true).should == "true"
    end

    it "should convert the boolean 'false' into the string 'false'" do
      @tester.serialize_value(false).should == "false"
    end

    it "should return all other values" do
      @tester.serialize_value("foo").should == "foo"
    end
  end

  describe "when unserializing" do
    it "should yaml-load values that look like yaml" do
      yaml = YAML.dump(%w{a b c})
      @tester.unserialize_value(yaml).should == %w{a b c}
    end

    it "should convert the string 'true' into the boolean 'true'" do
      @tester.unserialize_value("true").should == true
    end

    it "should convert the string 'false' into the boolean 'false'" do
      @tester.unserialize_value("false").should == false
    end

    it "should return all other values" do
      @tester.unserialize_value("foo").should == "foo"
    end
  end
end
