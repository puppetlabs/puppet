require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet_spec/files'

require 'puppet/dsl/helper'

include PuppetSpec::DSL
include PuppetSpec::Files

describe Puppet::DSL::Helper do
  before :each do
    @helper = mock
    @helper.extend Puppet::DSL::Helper
  end

  it "should define class methods too" do
    class A
      include Puppet::DSL::Helper
    end

    A.new.should respond_to :is_ruby_dsl?
    A.should     respond_to :is_ruby_dsl?
  end

  describe "#is_ruby_dsl?" do
    it "returns true when Ruby filename is passed as an argument" do
      @helper.is_ruby_dsl?("test.rb").should be true
    end

    it "returns false when not Ruby filename is passed as an argument" do
      @helper.is_ruby_dsl?("test").should be false
    end
  end

  describe "#is_puppet_dsl?" do

    it "returns true when Puppet filename is passed as an argument" do
      @helper.is_puppet_dsl?("test.pp").should be true
    end

    it "returns true when non-Puppet filename is passed as an argument" do
      @helper.is_puppet_dsl?("test").should be true
    end

    it "returns false when Ruby filename is passed as an argument" do
      @helper.is_puppet_dsl?("test.rb").should be false
    end
  end

  describe "#canonize_type" do
    it "should return canonical type name" do
      ["FiLe", "fIlE", "fILE", "File", "file", "FILE"].each do |f|
        @helper.canonize_type(f).should == "File"
      end
    end
  end

  describe "#is_resource_type?" do
    before :each do
      prepare_compiler_and_scope
    end

    it "should return true when type is a class" do
      evaluate_in_scope do
        @helper.is_resource_type?(:class).should be true
      end
    end

    it "should return true when type is a node" do
      evaluate_in_scope do
        @helper.is_resource_type?(:node).should be true
      end
    end

    it "should return true when type is a builtin type" do
      evaluate_in_scope do
        @helper.is_resource_type?(:file).should be true
      end
    end

    it "should return true when type is defined in manifests" do
      evaluate_in_context { define(:foo) {} }
      evaluate_in_scope do
        @helper.is_resource_type?(:foo).should be true
      end
    end

    it "should return false otherwise" do
      evaluate_in_scope do
        @helper.is_resource_type?(:asdasdasfasf).should be false
      end
    end

  end

  describe "#is_function?" do
    it "should return true when a puppet function exists" do
      @helper.is_function?("notice").should be true
    end

    it "should return false otherwise" do
      @helper.is_function?("asdfasdf").should be false
    end
  end

  describe "#get_resource" do
    it "should return the reference if it's already a resource" do
      ref = Puppet::Resource.new "foo", "bar"
      @helper.get_resource(ref).should == ref
    end

    it "should get a resource from Puppet::DSL::ResourceReference" do
      prepare_compiler_and_scope
      res = evaluate_in_context { file "foo" }.first
      ref = evaluate_in_context { type("file")["foo"] }
      @helper.get_resource(ref).should == res
    end

    it "should get a resource from a string" do
      prepare_compiler_and_scope
      res = evaluate_in_context { file "foo" }.first
      evaluate_in_scope { @helper.get_resource("File[foo]").should == res }
    end

    it "should return nil when the string reference doesn't exist" do
      prepare_compiler_and_scope
      evaluate_in_scope { @helper.get_resource("File[foo]").should == nil }
    end

    it "should return nil otherwise" do
      @helper.get_resource(3).should == nil
    end

  end
end

