require 'spec_helper'
require 'hiera/scope'

require 'puppet_spec/scope'

describe Hiera::Scope do
  include PuppetSpec::Scope

  let(:real) { create_test_scope_for_node("test_node") }
  let(:scope) { Hiera::Scope.new(real) }

  describe "#initialize" do
    it "should store the supplied puppet scope" do
      expect(scope.real).to eq(real)
    end
  end

  describe "#[]" do
    it "should return nil when no value is found" do
      expect(scope["foo"]).to eq(nil)
    end

    it "should treat '' as nil" do
      real["foo"] = ""

      expect(scope["foo"]).to eq(nil)
    end

    it "should return found data" do
      real["foo"] = "bar"

      expect(scope["foo"]).to eq("bar")
    end

    it "preserves the case of a string that is found" do
      real["foo"] = "CAPITAL!"

      expect(scope["foo"]).to eq("CAPITAL!")
    end

    it "aliases $module_name as calling_module" do
      real["module_name"] = "the_module"

      expect(scope["calling_module"]).to eq("the_module")
    end

    it "uses the name of the of the scope's class as the calling_class" do
      real.source = Puppet::Resource::Type.new(:hostclass,
                                               "testing",
                                               :module_name => "the_module")

      expect(scope["calling_class"]).to eq("testing")
    end

    it "downcases the calling_class" do
      real.source = Puppet::Resource::Type.new(:hostclass,
                                               "UPPER CASE",
                                               :module_name => "the_module")

      expect(scope["calling_class"]).to eq("upper case")
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

      expect(scope["calling_class"]).to eq("name_of_the_class_including_the_definition")
    end
  end

  describe "#exist?" do
    it "should correctly report missing data" do
      real["nil_value"] = nil
      real["blank_value"] = ""

      expect(scope.exist?("nil_value")).to eq(true)
      expect(scope.exist?("blank_value")).to eq(true)
      expect(scope.exist?("missing_value")).to eq(false)
    end

    it "should always return true for calling_class and calling_module" do
      expect(scope.include?("calling_class")).to eq(true)
      expect(scope.include?("calling_class_path")).to eq(true)
      expect(scope.include?("calling_module")).to eq(true)
    end
  end
end
