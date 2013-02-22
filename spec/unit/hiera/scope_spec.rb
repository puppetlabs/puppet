require 'spec_helper'
require 'hiera/scope'

describe Hiera::Scope do
  let(:real) { Puppet::Parser::Scope.new_for_test_harness("test_node") }
  let(:scope) { Hiera::Scope.new(real) }

  describe "#initialize" do
    it "should store the supplied puppet scope" do
      scope.real.should == real
    end
  end

  describe "#[]" do
    it "should return nil when no value is found" do
      scope["foo"].should == nil
    end

    it "should treat '' as nil" do
      real["foo"] = ""

      scope["foo"].should == nil
    end

    it "sould return found data" do
      real["foo"] = "bar"

      scope["foo"].should == "bar"
    end

    it "should get calling_class and calling_module from puppet scope" do
      source = mock
      source.expects(:type).returns(:hostclass).once
      source.expects(:name).returns("Foo::Bar").once
      source.expects(:module_name).returns("foo").once
      real.expects(:source).returns(source).at_least_once

      scope["calling_class"].should == "foo::bar"
      scope["calling_module"].should == "foo"
    end
  end

  describe "#include?" do
    it "should correctly report missing data" do
      real["foo"] = ""

      scope.include?("foo").should == false
    end

    it "should always return true for calling_class and calling_module" do
      scope.include?("calling_class").should == true
      scope.include?("calling_module").should == true
    end
  end
end
