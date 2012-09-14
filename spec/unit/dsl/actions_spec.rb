require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/actions'

include PuppetSpec::DSL

describe Puppet::DSL::Actions do
  subject       { Puppet::DSL::Actions.new :undefined }
  before(:each) { prepare_compiler_and_scope        }

  describe "#type_reference" do
    it "returns a type reference object" do
      evaluate_in_scope do
        subject.type_reference("file").should be_a Puppet::DSL::TypeReference
      end
    end

    it "returns a type reference for a given type" do
      evaluate_in_scope do
        subject.type_reference("file").type.should == "File"
      end
    end
  end

  describe "#is_resource_type?" do

    it "should return true when type is a class" do
      evaluate_in_scope do
        subject.is_resource_type?(:class).should be true
      end
    end

    it "should return true when type is a node" do
      evaluate_in_scope do
        subject.is_resource_type?(:node).should be true
      end
    end

    it "should return true when type is a builtin type" do
      evaluate_in_scope do
        subject.is_resource_type?(:file).should be true
      end
    end

    it "should return true when type is defined in manifests" do
      evaluate_in_context { define(:foo) {} }
      evaluate_in_scope do
        subject.is_resource_type?(:foo).should be true
      end
    end

    it "should return false otherwise" do
      evaluate_in_scope do
        subject.is_resource_type?(:asdasdasfasf).should be false
      end
    end

  end

  describe "#is_function?" do
    it "should return true when a puppet function exists" do
      subject.is_function?("notice").should be true
    end

    it "should return false otherwise" do
      subject.is_function?("asdfasdf").should be false
    end
  end

  describe "#get_resource" do
    it "should return the reference if it's already a resource" do
      ref = Puppet::Resource.new "foo", "bar"
      subject.send(:get_resource, ref).should == ref
    end

    it "should get a resource from Puppet::DSL::ResourceReference" do
      prepare_compiler_and_scope
      res = evaluate_in_context { file "foo" }.first
      ref = evaluate_in_context { type("file")["foo"] }
      subject.send(:get_resource, ref).should == res
    end

    it "should get a resource from a string" do
      prepare_compiler_and_scope
      res = evaluate_in_context { file "foo" }.first
      evaluate_in_scope { subject.send(:get_resource, "File[foo]").should == res }
    end

    it "should return a string when the string reference doesn't exist" do
      prepare_compiler_and_scope
      reference = "File[foo]"
      evaluate_in_scope { subject.send(:get_resource, reference).should == reference }
    end

    it "should stringify the parameter when resource can't be found" do
      prepare_compiler_and_scope
      evaluate_in_scope { subject.send(:get_resource, 3).should == "3" }
    end
  end

  describe "#params" do
    it "returns current scope" do
      evaluate_in_scope do
        subject.params.should == Puppet::DSL::Parser.current_scope
      end
    end

  end

  describe "#create_node" do
    it "raises NoMethodError when called from invalid nesting" do
      lambda do
        subject.create_node "foo", {}, proc {}, 1
      end.should raise_error NoMethodError
    end

    it "raises ArgumentError when code is nil" do
      lambda do
        subject.create_node "foo", {}, nil, 0
      end.should raise_error ArgumentError
    end

    it "creates a new puppet node" do
      evaluate_in_scope do
        subject.create_node("foo", {}, proc {}, 0).tap do |r|
          r.type.should == :node
          r.name.should == "foo"
        end.should be_a Puppet::Resource::Type
      end
    end

    it "allows to pass a regex instead of name" do
      evaluate_in_scope do
        subject.create_node(/foo/, {}, proc {}, 0).tap do |r|
          r.name_is_regex?.should be true
        end.should be_a Puppet::Resource::Type
      end
    end

    it "sets options for puppet node" do
      evaluate_in_scope do
        subject.create_node("foo", {:inherits => "bar"}, proc {}, 0).parent.should == "bar"
      end
    end

    it "adds the node to known resource types" do
      evaluate_in_scope do
        resource_types = mock
        resource_types.expects(:add_node).with {|n| n.type == :node }
        resource_types.stubs(:hostclass).returns nil
        @scope.stubs(:known_resource_types).returns resource_types

        subject.create_node "foo", {}, proc {}, 0
      end
    end

    it "sets ruby code for the node" do
      block   = proc {}
      context = mock "Context"
      Puppet::DSL::Context.expects(:new).with {|code, _| code == block}.returns context
      evaluate_in_scope do
        subject.create_node("foo", {}, block, 0).ruby_code.should include context
      end
    end
  end

  describe "#create_hostclass" do
    it "raises NoMethodError when called from invalid nesting" do
      lambda do
        subject.create_hostclass :foo, {}, proc {}, 1
      end.should raise_error NoMethodError
    end

    it "raises ArgumentError when code is nil" do
      lambda do
        subject.create_hostclass :foo, {}, nil, 0
      end.should raise_error ArgumentError
    end

    it "creates a new puppet hostclass" do
      evaluate_in_scope do
        subject.create_hostclass(:foo, {}, proc {}, 0).tap do |r|
          r.type.should == :hostclass
          r.name.should == "foo"
        end.should be_a Puppet::Resource::Type
      end
    end

    it "sets options for puppet hostclass" do
      evaluate_in_scope do
        subject.create_hostclass(:foo, {:inherits => :bar, :arguments => {:myparam => 3}}, proc {}, 0).tap do |r|
          r.parent.should    == "bar"
          r.arguments.should == {"myparam" => 3}
        end
      end
    end

    it "adds the hostclass to resource type collection" do
      evaluate_in_scope do
        resource_types = mock
        resource_types.expects(:add_hostclass).with {|n| n.type == :hostclass }
        @scope.stubs(:known_resource_types).returns resource_types

        subject.create_hostclass :foo, {}, proc {}, 0
      end
    end

    it "sets ruby code for hostclass" do
      block   = proc {}
      context = mock "Context"
      Puppet::DSL::Context.expects(:new).with {|code, _| code == block}.returns context
      evaluate_in_scope do
        subject.create_hostclass(:foo, {}, block, 0).ruby_code.should include context
      end
    end
  end

  describe "#create_definition" do
    it "raises NoMethodError when called from invalid nesting" do
      lambda do
        subject.create_definition :foo, {}, proc {}, 1
      end.should raise_error NoMethodError
    end

    it "raises ArgumentError when code is nil" do
      lambda do
        subject.create_definition :foo, {}, nil, 0
      end.should raise_error ArgumentError
    end

    it "creates new definition" do
      evaluate_in_scope do
        subject.create_definition(:foo, {}, proc {}, 0).tap do |r|
          r.should be_a Puppet::Resource::Type
          r.type.should == :definition
          r.name.should == "foo"
        end
      end

    end

    it "set options for the definition" do
      evaluate_in_scope do
        subject.create_definition(:foo, {:arguments => {:param => 42}}, proc {}, 0).arguments.should == {"param" => 42}
      end
    end

    it "adds definition to known resource types" do
      evaluate_in_scope do
        resource_types = mock
        resource_types.expects(:add_definition).with {|n| n.type == :definition }
        @scope.stubs(:known_resource_types).returns resource_types

        subject.create_definition :foo, {}, proc {}, 0
      end

    end

    it "sets ruby code for definition" do
      block   = proc {}
      context = mock "Context"
      Puppet::DSL::Context.expects(:new).with {|code, _| code == block}.returns context
      evaluate_in_scope do
        subject.create_definition(:foo, {}, block, 0).ruby_code.should include context
      end
    end
  end

  describe "#create_resource" do
    it "raises NoMethodError when importing" do
      evaluate_in_scope nil do
        lambda { subject.create_resource :notify, "message", {}, nil }.should raise_error NoMethodError
      end
    end

    it "creates the resource when the type exists" do
      @scope.compiler.expects(:add_resource).with { |scope, resource| scope == @scope and resource.is_a? Puppet::Parser::Resource }

      evaluate_in_scope do
        subject.create_resource :notify, "foo", {}, nil
      end
    end

    it "returns an array of created resources" do
      evaluate_in_scope do
        subject.create_resource(:notify, ["foo", "bar"], {}, nil).map(&:title).should == ["foo", "bar"]
      end
    end

    it "sets the passed options to it" do
      evaluate_in_scope do
        resource = subject.create_resource(:file, "/tmp/test", {:ensure => :present, :mode => "0666"}, nil).first
        resource[:ensure].should == "present"
        resource[:mode].should   == "0666"
      end
    end

    it "evaluates options passed in block" do
      evaluate_in_scope do
        block = proc do |resource|
          resource.ensure = :present
          resource.mode   = "0666"
        end

        resource = subject.create_resource(:file, "/tmp/foo", {}, block).first
        resource[:ensure].should == "present"
        resource[:mode].should   == "0666"
      end
    end

    context "when virtualizing" do
      it "creates virtual resource when called from virtual scope" do
        evaluate_in_scope do
          subject.virtualizing = true

          subject.create_resource(:notify, "foo", {}, nil).first.virtual.should be true
        end
      end

      it "creates virtual resource when passed virtual option" do
        evaluate_in_scope do
          subject.create_resource(:notify, "foo", {:virtual => true}, nil).first.virtual.should be true
        end
      end
    end

    context "when exporting" do
      it "creates exported resource when called from exporting scope" do
        evaluate_in_scope do
          subject.exporting = true

          subject.create_resource(:notify, "foo", {}, nil).first.exported.should be true
        end
      end

      it "creates exported resource when passed export option" do
        evaluate_in_scope do
          subject.create_resource(:notify, "foo", {:export => true}, nil).first.exported.should be true
        end
      end
    end
  end

  describe "#call_function" do
    it "raises NoMethodError when importing" do
      evaluate_in_scope nil do
        lambda { subject.call_function "notice", [] }.should raise_error NoMethodError
      end
    end

    it "calls the function and passes the array of arguments when it exists" do
      @scope.expects(:notice).with(["foo", "bar"])
      evaluate_in_scope do
        subject.call_function "notice", ["foo", "bar"]
      end
    end
  end

  describe "#validate_options" do
    let(:attributes) { {:foo => "bar"} }

    it "raises ArgumentError when invalid options are passed" do
      lambda do
        subject.validate_options :asdf, attributes
      end.should raise_error ArgumentError
    end

    it "does nothing when all attributes are valid" do
      lambda do
        subject.validate_options :foo, attributes
      end.should_not raise_error ArgumentError
    end
  end

  it "allows to read and set exporting setting" do
    subject.exporting?.should be false
    subject.exporting = true
    subject.exporting?.should be true
    subject.exporting = false
    subject.exporting?.should be false
  end

  it "allows to read and set virtualizing setting" do
    subject.virtualizing?.should be false
    subject.virtualizing = true
    subject.virtualizing?.should be true
    subject.virtualizing = false
    subject.virtualizing?.should be false
  end

end

