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

    A.new.should respond_to :dsl_type_for
    A.should respond_to :dsl_type_for
  end

  describe "#dsl_type_for" do

    it "should return :ruby when the manifest name ends with .rb" do
      Puppet[:manifest] = "test.rb"
      @helper.dsl_type_for(nil).should == :ruby
    end

    it "should return :puppet when the manifest name ends with .pp" do
      Puppet[:manifest] = "test.pp"
      @helper.dsl_type_for(nil).should == :puppet
    end

    it "should return :puppet when the manifest name is blank" do
      Puppet[:manifest] = ""
      @helper.dsl_type_for(nil).should == :puppet
    end
  end

  describe "#use_ruby_dsl?" do
    it "should return true when #dsl_type_for returns :ruby" do
      @helper.expects(:dsl_type_for).with(nil).returns :ruby
      @helper.use_ruby_dsl?(nil).should == true
    end

    it "should return false when #dsl_type_for returns :puppet" do
      @helper.expects(:dsl_type_for).with(nil).returns :puppet
      @helper.use_ruby_dsl?(nil).should == false
    end
  end

  describe "#use_puppet_dsl?" do

    it "should return false when #dsl_type_for returns :ruby" do
      @helper.expects(:dsl_type_for).at_least_once.with(nil).returns :ruby
      @helper.use_puppet_dsl?(nil).should be false
    end

    it "should return true when #dsl_type_for returns :puppet" do
      @helper.expects(:dsl_type_for).at_least_once.with(nil).returns :puppet
      @helper.use_puppet_dsl?(nil).should be true
    end

  end

  describe "#get_ruby_code" do

    it "should return :code despite :manifest is set" do
      Puppet[:code] = "test string"
      Puppet[:manifest] = "test.rb"

      @helper.get_ruby_code(nil).should == "test string"
    end

    it "should read the contents of the :manifest" do
      filename = tmpfile ["test", ".rb"]
      File.open filename, "w" do |f|
        f << "test file contents"
      end
      Puppet[:manifest] = filename
      @helper.get_ruby_code(nil).should == "test file contents"
    end

    it "should raise when not using ruby dsl" do
      Puppet[:manifest] = "test.pp"
      lambda do
        @helper.get_ruby_code nil
      end.should raise_error
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

    it "should fail otherwise" do
      lambda do
      @helper.get_resource 3
      end.should raise_error ArgumentError
    end

  end
end

