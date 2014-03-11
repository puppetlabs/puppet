require 'spec_helper'
require 'hiera/scope'

require 'puppet_spec/scope'

describe Hiera::Scope do
  include PuppetSpec::Scope

  let(:real) { create_test_scope_for_node("test_node") }
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

    it "should return found data" do
      real["foo"] = "bar"

      scope["foo"].should == "bar"
    end

    it "preserves the case of a string that is found" do
      real["foo"] = "CAPITAL!"

      scope["foo"].should == "CAPITAL!"
    end

    it "aliases $module_name as calling_module" do
      real["module_name"] = "the_module"

      scope["calling_module"].should == "the_module"
    end

    it "uses the name of the of the scope's class as the calling_class" do
      real.source = Puppet::Resource::Type.new(:hostclass,
                                               "testing",
                                               :module_name => "the_module")

      scope["calling_class"].should == "testing"
    end

    it "downcases the calling_class" do
      real.source = Puppet::Resource::Type.new(:hostclass,
                                               "UPPER CASE",
                                               :module_name => "the_module")

      scope["calling_class"].should == "upper case"
    end

    it "looks for the class which includes the defined type as the calling_class" do
      parent = create_test_scope_for_node("parent")
      real.parent = parent
      parent.source = Puppet::Resource::Type.new(:hostclass,
                                                 "name_of_the_class_including_the_definition",
                                                 :module_name => "class_module")
      real.source = Puppet::Resource::Type.new(:definition,
                                               "definition_name",
                                               :module_name => "definition_module")

      scope["calling_class"].should == "name_of_the_class_including_the_definition"
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
