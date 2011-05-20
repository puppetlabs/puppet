#!/usr/bin/env rspec
require 'spec_helper'

# LAK: FIXME This is just new tests for resources; I have
# not moved all tests over yet.

describe Puppet::Parser::Resource do
  before do
    @node = Puppet::Node.new("yaynode")
    @known_resource_types = Puppet::Resource::TypeCollection.new("env")
    @compiler = Puppet::Parser::Compiler.new(@node)
    @compiler.environment.stubs(:known_resource_types).returns @known_resource_types
    @source = newclass ""
    @scope = @compiler.topscope
  end

  def mkresource(args = {})
    args[:source] ||= @source
    args[:scope] ||= @scope

    params = args[:parameters] || {:one => "yay", :three => "rah"}
    if args[:parameters] == :none
      args.delete(:parameters)
    elsif not args[:parameters].is_a? Array
      args[:parameters] = paramify(args[:source], params)
    end

    Puppet::Parser::Resource.new("resource", "testing", args)
  end

  def param(name, value, source)
    Puppet::Parser::Resource::Param.new(:name => name, :value => value, :source => source)
  end

  def paramify(source, hash)
    hash.collect do |name, value|
      Puppet::Parser::Resource::Param.new(
        :name => name, :value => value, :source => source
      )
    end
  end

  def newclass(name)
    @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
  end

  def newdefine(name)
    @known_resource_types.add Puppet::Resource::Type.new(:definition, name)
  end

  def newnode(name)
    @known_resource_types.add Puppet::Resource::Type.new(:node, name)
  end

  it "should use the file lookup module" do
    Puppet::Parser::Resource.ancestors.should be_include(Puppet::FileCollection::Lookup)
  end

  it "should get its environment from its scope" do
    scope = stub 'scope', :source => stub("source"), :namespaces => nil
    scope.expects(:environment).returns("foo").at_least_once
    Puppet::Parser::Resource.new("file", "whatever", :scope => scope).environment.should == "foo"
  end

  it "should use the resource type collection helper module" do
    Puppet::Parser::Resource.ancestors.should be_include(Puppet::Resource::TypeCollectionHelper)
  end

  it "should use the scope's environment as its environment" do
    @scope.expects(:environment).returns("myenv").at_least_once
    Puppet::Parser::Resource.new("file", "whatever", :scope => @scope).environment.should == "myenv"
  end

  it "should be isomorphic if it is builtin and models an isomorphic type" do
    Puppet::Type.type(:file).expects(:isomorphic?).returns(true)
    @resource = Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source).isomorphic?.should be_true
  end

  it "should not be isomorphic if it is builtin and models a non-isomorphic type" do
    Puppet::Type.type(:file).expects(:isomorphic?).returns(false)
    @resource = Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source).isomorphic?.should be_false
  end

  it "should be isomorphic if it is not builtin" do
    newdefine "whatever"
    @resource = Puppet::Parser::Resource.new("whatever", "whatever", :scope => @scope, :source => @source).isomorphic?.should be_true
  end

  it "should have a array-indexing method for retrieving parameter values" do
    @resource = mkresource
    @resource[:one].should == "yay"
  end

  it "should use a Puppet::Resource for converting to a ral resource" do
    trans = mock 'resource', :to_ral => "yay"
    @resource = mkresource
    @resource.expects(:to_resource).returns trans
    @resource.to_ral.should == "yay"
  end

  it "should be able to use the indexing operator to access parameters" do
    resource = Puppet::Parser::Resource.new("resource", "testing", :source => "source", :scope => @scope)
    resource["foo"] = "bar"
    resource["foo"].should == "bar"
  end

  it "should return the title when asked for a parameter named 'title'" do
    Puppet::Parser::Resource.new("resource", "testing", :source => @source, :scope => @scope)[:title].should == "testing"
  end

  describe "when initializing" do
    before do
      @arguments = {:scope => @scope}
    end

    it "should fail unless #{name.to_s} is specified", :'fails_on_ruby_1.9.2' => true do
      lambda { Puppet::Parser::Resource.new('file', '/my/file') }.should raise_error(ArgumentError)
    end

    it "should set the reference correctly" do
      res = Puppet::Parser::Resource.new("resource", "testing", @arguments)
      res.ref.should == "Resource[testing]"
    end

    it "should be tagged with user tags" do
      tags = [ "tag1", "tag2" ]
      @arguments[:parameters] = [ param(:tag, tags , :source) ]
      res = Puppet::Parser::Resource.new("resource", "testing", @arguments)
      (res.tags & tags).should == tags
    end
  end

  describe "when evaluating" do
    before do
      @node = Puppet::Node.new "test-node"
      @compiler = Puppet::Parser::Compiler.new @node
      @catalog = Puppet::Resource::Catalog.new
      source = stub('source')
      source.stubs(:module_name)
      @scope = Puppet::Parser::Scope.new(:compiler => @compiler, :source => source)
      @catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => @scope))
    end

    it "should evaluate the associated AST definition" do
      definition = newdefine "mydefine"
      res = Puppet::Parser::Resource.new("mydefine", "whatever", :scope => @scope, :source => @source, :catalog => @catalog)
      definition.expects(:evaluate_code).with(res)

      res.evaluate
    end

    it "should evaluate the associated AST class" do
      @class = newclass "myclass"
      res = Puppet::Parser::Resource.new("class", "myclass", :scope => @scope, :source => @source, :catalog => @catalog)
      @class.expects(:evaluate_code).with(res)
      res.evaluate
    end

    it "should evaluate the associated AST node" do
      nodedef = newnode("mynode")
      res = Puppet::Parser::Resource.new("node", "mynode", :scope => @scope, :source => @source, :catalog => @catalog)
      nodedef.expects(:evaluate_code).with(res)
      res.evaluate
    end

    it "should add an edge to any specified stage for class resources", :'fails_on_ruby_1.9.2' => true do
      @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", '')

      other_stage = Puppet::Parser::Resource.new(:stage, "other", :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, other_stage)
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'other'
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      @compiler.catalog.edge?(other_stage, resource).should be_true
    end

    it "should fail if an unknown stage is specified", :'fails_on_ruby_1.9.2' => true do
      @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", '')

      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'other'

      lambda { resource.evaluate }.should raise_error(ArgumentError, /Could not find stage other specified by/)
    end

    it "should add edges from the class resources to the parent's stage if no stage is specified", :'fails_on_ruby_1.9.2' => true do
      main      = @compiler.catalog.resource(:stage, :main)
      foo_stage = Puppet::Parser::Resource.new(:stage, :foo_stage, :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, foo_stage)
      @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", '')
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      resource[:stage] = 'foo_stage'
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      @compiler.catalog.should be_edge(foo_stage, resource)
    end

    it "should add edges from top-level class resources to the main stage if no stage is specified", :'fails_on_ruby_1.9.2' => true do
      main = @compiler.catalog.resource(:stage, :main)
      @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "foo", '')
      resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope, :catalog => @catalog)
      @compiler.add_resource(@scope, resource)

      resource.evaluate

      @compiler.catalog.should be_edge(main, resource)
    end
  end

  describe "when finishing" do
    before do
      @class = newclass "myclass"
      @nodedef = newnode("mynode")

      @resource = Puppet::Parser::Resource.new("file", "whatever", :scope => @scope, :source => @source)
    end

    it "should do nothing if it has already been finished" do
      @resource.finish
      @resource.expects(:add_metaparams).never
      @resource.finish
    end

    it "should add all defaults available from the scope" do
      @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => param(:owner, "default", @resource.source))
      @resource.finish

      @resource[:owner].should == "default"
    end

    it "should not replace existing parameters with defaults" do
      @resource.set_parameter :owner, "oldvalue"
      @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => :replaced)
      @resource.finish

      @resource[:owner].should == "oldvalue"
    end

    it "should add a copy of each default, rather than the actual default parameter instance" do
      newparam = param(:owner, "default", @resource.source)
      other = newparam.dup
      other.value = "other"
      newparam.expects(:dup).returns(other)
      @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => newparam)
      @resource.finish

      @resource[:owner].should == "other"
    end

    it "should be running in metaparam compatibility mode if running a version below 0.25" do
      catalog = stub 'catalog', :client_version => "0.24.8"
      @resource.stubs(:catalog).returns catalog
      @resource.should be_metaparam_compatibility_mode
    end

    it "should be running in metaparam compatibility mode if running no client version is available" do
      catalog = stub 'catalog', :client_version => nil
      @resource.stubs(:catalog).returns catalog
      @resource.should be_metaparam_compatibility_mode
    end

    it "should not be running in metaparam compatibility mode if running a version at or above 0.25" do
      catalog = stub 'catalog', :client_version => "0.25.0"
      @resource.stubs(:catalog).returns catalog
      @resource.should_not be_metaparam_compatibility_mode
    end

    it "should not copy relationship metaparams when not in metaparam compatibility mode" do
      @scope.setvar("require", "bar")

      @resource.stubs(:metaparam_compatibility_mode?).returns false
      @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

      @resource["require"].should be_nil
    end

    it "should copy relationship metaparams when in metaparam compatibility mode" do
      @scope.setvar("require", "bar")

      @resource.stubs(:metaparam_compatibility_mode?).returns true
      @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

      @resource["require"].should == "bar"
    end

    it "should stack relationship metaparams when in metaparam compatibility mode" do
      @resource.set_parameter("require", "foo")
      @scope.setvar("require", "bar")

      @resource.stubs(:metaparam_compatibility_mode?).returns true
      @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

      @resource["require"].should == ["foo", "bar"]
    end
  end

  describe "when being tagged" do
    before do
      @scope_resource = stub 'scope_resource', :tags => %w{srone srtwo}
      @scope.stubs(:resource).returns @scope_resource
      @resource = Puppet::Parser::Resource.new("file", "yay", :scope => @scope, :source => mock('source'))
    end

    it "should get tagged with the resource type" do
      @resource.tags.should be_include("file")
    end

    it "should get tagged with the title" do
      @resource.tags.should be_include("yay")
    end

    it "should get tagged with each name in the title if the title is a qualified class name" do
      resource = Puppet::Parser::Resource.new("file", "one::two", :scope => @scope, :source => mock('source'))
      resource.tags.should be_include("one")
      resource.tags.should be_include("two")
    end

    it "should get tagged with each name in the type if the type is a qualified class name" do
      resource = Puppet::Parser::Resource.new("one::two", "whatever", :scope => @scope, :source => mock('source'))
      resource.tags.should be_include("one")
      resource.tags.should be_include("two")
    end

    it "should not get tagged with non-alphanumeric titles" do
      resource = Puppet::Parser::Resource.new("file", "this is a test", :scope => @scope, :source => mock('source'))
      resource.tags.should_not be_include("this is a test")
    end

    it "should fail on tags containing '*' characters" do
      lambda { @resource.tag("bad*tag") }.should raise_error(Puppet::ParseError)
    end

    it "should fail on tags starting with '-' characters" do
      lambda { @resource.tag("-badtag") }.should raise_error(Puppet::ParseError)
    end

    it "should fail on tags containing ' ' characters" do
      lambda { @resource.tag("bad tag") }.should raise_error(Puppet::ParseError)
    end

    it "should allow alpha tags" do
      lambda { @resource.tag("good_tag") }.should_not raise_error(Puppet::ParseError)
    end
  end

  describe "when merging overrides" do
    before do
      @source = "source1"
      @resource = mkresource :source => @source
      @override = mkresource :source => @source
    end

    it "should fail when the override was not created by a parent class" do
      @override.source = "source2"
      @override.source.expects(:child_of?).with("source1").returns(false)
      lambda { @resource.merge(@override) }.should raise_error(Puppet::ParseError)
    end

    it "should succeed when the override was created in the current scope" do
      @resource.source = "source3"
      @override.source = @resource.source
      @override.source.expects(:child_of?).with("source3").never
      params = {:a => :b, :c => :d}
      @override.expects(:parameters).returns(params)
      @resource.expects(:override_parameter).with(:b)
      @resource.expects(:override_parameter).with(:d)
      @resource.merge(@override)
    end

    it "should succeed when a parent class created the override" do
      @resource.source = "source3"
      @override.source = "source4"
      @override.source.expects(:child_of?).with("source3").returns(true)
      params = {:a => :b, :c => :d}
      @override.expects(:parameters).returns(params)
      @resource.expects(:override_parameter).with(:b)
      @resource.expects(:override_parameter).with(:d)
      @resource.merge(@override)
    end

    it "should add new parameters when the parameter is not set" do
      @source.stubs(:child_of?).returns true
      @override.set_parameter(:testing, "value")
      @resource.merge(@override)

      @resource[:testing].should == "value"
    end

    it "should replace existing parameter values" do
      @source.stubs(:child_of?).returns true
      @resource.set_parameter(:testing, "old")
      @override.set_parameter(:testing, "value")

      @resource.merge(@override)

      @resource[:testing].should == "value"
    end

    it "should add values to the parameter when the override was created with the '+>' syntax" do
      @source.stubs(:child_of?).returns true
      param = Puppet::Parser::Resource::Param.new(:name => :testing, :value => "testing", :source => @resource.source)
      param.add = true

      @override.set_parameter(param)

      @resource.set_parameter(:testing, "other")

      @resource.merge(@override)

      @resource[:testing].should == %w{other testing}
    end

    it "should not merge parameter values when multiple resources are overriden with '+>' at once " do
      @resource_2 = mkresource :source => @source

      @resource.  set_parameter(:testing, "old_val_1")
      @resource_2.set_parameter(:testing, "old_val_2")

      @source.stubs(:child_of?).returns true
      param = Puppet::Parser::Resource::Param.new(:name => :testing, :value => "new_val", :source => @resource.source)
      param.add = true
      @override.set_parameter(param)

      @resource.  merge(@override)
      @resource_2.merge(@override)

      @resource  [:testing].should == %w{old_val_1 new_val}
      @resource_2[:testing].should == %w{old_val_2 new_val}
    end

    it "should promote tag overrides to real tags" do
      @source.stubs(:child_of?).returns true
      param = Puppet::Parser::Resource::Param.new(:name => :tag, :value => "testing", :source => @resource.source)

      @override.set_parameter(param)

      @resource.merge(@override)

      @resource.tagged?("testing").should be_true
    end

  end

  it "should be able to be converted to a normal resource" do
    @source = stub 'scope', :name => "myscope"
    @resource = mkresource :source => @source
    @resource.should respond_to(:to_resource)
  end

  it "should use its resource converter to convert to a transportable resource" do
    @source = stub 'scope', :name => "myscope"
    @resource = mkresource :source => @source

    newresource = Puppet::Resource.new(:file, "/my")
    Puppet::Resource.expects(:new).returns(newresource)

    newresource.expects(:to_trans).returns "mytrans"

    @resource.to_trans.should == "mytrans"
  end

  it "should return nil if converted to a transportable resource and it is virtual" do
    @source = stub 'scope', :name => "myscope"
    @resource = mkresource :source => @source

    @resource.expects(:virtual?).returns true
    @resource.to_trans.should be_nil
  end

  describe "when being converted to a resource" do
    before do
      @parser_resource = mkresource :scope => @scope, :parameters => {:foo => "bar", :fee => "fum"}
    end

    it "should create an instance of Puppet::Resource" do
      @parser_resource.to_resource.should be_instance_of(Puppet::Resource)
    end

    it "should set the type correctly on the Puppet::Resource" do
      @parser_resource.to_resource.type.should == @parser_resource.type
    end

    it "should set the title correctly on the Puppet::Resource" do
      @parser_resource.to_resource.title.should == @parser_resource.title
    end

    it "should copy over all of the parameters" do
      result = @parser_resource.to_resource.to_hash

      # The name will be in here, also.
      result[:foo].should == "bar"
      result[:fee].should == "fum"
    end

    it "should copy over the tags" do
      @parser_resource.tag "foo"
      @parser_resource.tag "bar"

      @parser_resource.to_resource.tags.should == @parser_resource.tags
    end

    it "should copy over the line" do
      @parser_resource.line = 40
      @parser_resource.to_resource.line.should == 40
    end

    it "should copy over the file" do
      @parser_resource.file = "/my/file"
      @parser_resource.to_resource.file.should == "/my/file"
    end

    it "should copy over the 'exported' value" do
      @parser_resource.exported = true
      @parser_resource.to_resource.exported.should be_true
    end

    it "should copy over the 'virtual' value" do
      @parser_resource.virtual = true
      @parser_resource.to_resource.virtual.should be_true
    end

    it "should convert any parser resource references to Puppet::Resource instances" do
      ref = Puppet::Resource.new("file", "/my/file")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ref}
      result = @parser_resource.to_resource
      result[:fee].should == Puppet::Resource.new(:file, "/my/file")
    end

    it "should convert any parser resource references to Puppet::Resource instances even if they are in an array" do
      ref = Puppet::Resource.new("file", "/my/file")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ["a", ref]}
      result = @parser_resource.to_resource
      result[:fee].should == ["a", Puppet::Resource.new(:file, "/my/file")]
    end

    it "should convert any parser resource references to Puppet::Resource instances even if they are in an array of array, and even deeper" do
      ref1 = Puppet::Resource.new("file", "/my/file1")
      ref2 = Puppet::Resource.new("file", "/my/file2")
      @parser_resource = mkresource :source => @source, :parameters => {:foo => "bar", :fee => ["a", [ref1,ref2]]}
      result = @parser_resource.to_resource
      result[:fee].should == ["a", Puppet::Resource.new(:file, "/my/file1"), Puppet::Resource.new(:file, "/my/file2")]
    end

    it "should fail if the same param is declared twice" do
      lambda do
        @parser_resource = mkresource :source => @source, :parameters => [
          Puppet::Parser::Resource::Param.new(
            :name => :foo, :value => "bar", :source => @source
          ),
          Puppet::Parser::Resource::Param.new(
            :name => :foo, :value => "baz", :source => @source
          )
        ]
      end.should raise_error(Puppet::ParseError)
    end
  end

  describe "when validating" do
    it "should check each parameter" do
      resource = Puppet::Parser::Resource.new :foo, "bar", :scope => @scope, :source => stub("source")
      resource[:one] = :two
      resource[:three] = :four
      resource.expects(:validate_parameter).with(:one)
      resource.expects(:validate_parameter).with(:three)
      resource.send(:validate)
    end

    it "should raise a parse error when there's a failure" do
      resource = Puppet::Parser::Resource.new :foo, "bar", :scope => @scope, :source => stub("source")
      resource[:one] = :two
      resource.expects(:validate_parameter).with(:one).raises ArgumentError
      lambda { resource.send(:validate) }.should raise_error(Puppet::ParseError)
    end
  end

  describe "when setting parameters" do
    before do
      @source = newclass "foobar"
      @resource = Puppet::Parser::Resource.new :foo, "bar", :scope => @scope, :source => @source
    end

    it "should accept Param instances and add them to the parameter list" do
      param = Puppet::Parser::Resource::Param.new :name => "foo", :value => "bar", :source => @source
      @resource.set_parameter(param)
      @resource["foo"].should == "bar"
    end

    it "should fail when provided a parameter name but no value" do
      lambda { @resource.set_parameter("myparam") }.should raise_error(ArgumentError)
    end

    it "should allow parameters to be set to 'false'" do
      @resource.set_parameter("myparam", false)
      @resource["myparam"].should be_false
    end

    it "should use its source when provided a parameter name and value" do
      @resource.set_parameter("myparam", "myvalue")
      @resource["myparam"].should == "myvalue"
    end
  end

  # part of #629 -- the undef keyword.  Make sure 'undef' params get skipped.
  it "should not include 'undef' parameters when converting itself to a hash" do
    resource = Puppet::Parser::Resource.new "file", "/tmp/testing", :source => mock("source"), :scope => mock("scope")
    resource[:owner] = :undef
    resource[:mode] = "755"
    resource.to_hash[:owner].should be_nil
  end
end
