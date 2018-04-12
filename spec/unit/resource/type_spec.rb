#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/resource/type'
require 'puppet/pops'
require 'matchers/json'

describe Puppet::Resource::Type do
  include JSONMatchers

  it "should have a 'name' attribute" do
    expect(Puppet::Resource::Type.new(:hostclass, "foo").name).to eq("foo")
  end

  [:code, :doc, :line, :file, :resource_type_collection].each do |attr|
    it "should have a '#{attr}' attribute" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      type.send(attr.to_s + "=", "yay")
      expect(type.send(attr)).to eq("yay")
    end
  end

  [:hostclass, :node, :definition].each do |type|
    it "should know when it is a #{type}" do
      expect(Puppet::Resource::Type.new(type, "foo").send("#{type}?")).to be_truthy
    end
  end

  describe "when a node"  do
    it "should allow a regex as its name" do
      expect { Puppet::Resource::Type.new(:node, /foo/) }.not_to raise_error
    end

    it "should allow an AST::HostName instance as its name" do
      regex = Puppet::Parser::AST::Regex.new(:value => /foo/)
      name = Puppet::Parser::AST::HostName.new(:value => regex)
      expect { Puppet::Resource::Type.new(:node, name) }.not_to raise_error
    end

    it "should match against the regexp in the AST::HostName when a HostName instance is provided" do
      regex = Puppet::Parser::AST::Regex.new(:value => /\w/)
      name = Puppet::Parser::AST::HostName.new(:value => regex)
      node = Puppet::Resource::Type.new(:node, name)

      expect(node.match("foo")).to be_truthy
    end

    it "should return the value of the hostname if provided a string-form AST::HostName instance as the name" do
      name = Puppet::Parser::AST::HostName.new(:value => "foo")
      node = Puppet::Resource::Type.new(:node, name)

      expect(node.name).to eq("foo")
    end

    describe "and the name is a regex" do
      it "should have a method that indicates that this is the case" do
        expect(Puppet::Resource::Type.new(:node, /w/)).to be_name_is_regex
      end

      it "should set its namespace to ''" do
        expect(Puppet::Resource::Type.new(:node, /w/).namespace).to eq("")
      end

      it "should return the regex converted to a string when asked for its name" do
        expect(Puppet::Resource::Type.new(:node, /ww/).name).to eq("__node_regexp__ww")
      end

      it "should downcase the regex when returning the name as a string" do
        expect(Puppet::Resource::Type.new(:node, /W/).name).to eq("__node_regexp__w")
      end

      it "should remove non-alpha characters when returning the name as a string" do
        expect(Puppet::Resource::Type.new(:node, /w*w/).name).not_to include("*")
      end

      it "should remove leading dots when returning the name as a string" do
        expect(Puppet::Resource::Type.new(:node, /.ww/).name).not_to match(/^\./)
      end

      it "should have a method for matching its regex name against a provided name" do
        expect(Puppet::Resource::Type.new(:node, /.ww/)).to respond_to(:match)
      end

      it "should return true when its regex matches the provided name" do
        expect(Puppet::Resource::Type.new(:node, /\w/).match("foo")).to be_truthy
      end

      it "should return true when its regex matches the provided name" do
        expect(Puppet::Resource::Type.new(:node, /\w/).match("foo")).to be_truthy
      end

      it "should return false when its regex does not match the provided name" do
        expect(!!Puppet::Resource::Type.new(:node, /\d/).match("foo")).to be_falsey
      end

      it "should return true when its name, as a string, is matched against an equal string" do
        expect(Puppet::Resource::Type.new(:node, "foo").match("foo")).to be_truthy
      end

      it "should return false when its name is matched against an unequal string" do
        expect(Puppet::Resource::Type.new(:node, "foo").match("bar")).to be_falsey
      end

      it "should match names insensitive to case" do
        expect(Puppet::Resource::Type.new(:node, "fOo").match("foO")).to be_truthy
      end
    end
  end

  describe "when initializing" do
    it "should require a resource super type" do
      expect(Puppet::Resource::Type.new(:hostclass, "foo").type).to eq(:hostclass)
    end

    it "should fail if provided an invalid resource super type" do
      expect { Puppet::Resource::Type.new(:nope, "foo") }.to raise_error(ArgumentError)
    end

    it "should set its name to the downcased, stringified provided name" do
      expect(Puppet::Resource::Type.new(:hostclass, "Foo::Bar".intern).name).to eq("foo::bar")
    end

    it "should set its namespace to the downcased, stringified qualified name for classes" do
      expect(Puppet::Resource::Type.new(:hostclass, "Foo::Bar::Baz".intern).namespace).to eq("foo::bar::baz")
    end

    [:definition, :node].each do |type|
      it "should set its namespace to the downcased, stringified qualified portion of the name for #{type}s" do
        expect(Puppet::Resource::Type.new(type, "Foo::Bar::Baz".intern).namespace).to eq("foo::bar")
      end
    end

    %w{code line file doc}.each do |arg|
      it "should set #{arg} if provided" do
        type = Puppet::Resource::Type.new(:hostclass, "foo", arg.to_sym => "something")
        expect(type.send(arg)).to eq("something")
      end
    end

    it "should set any provided arguments with the keys as symbols" do
      type = Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {:foo => "bar", :baz => "biz"})
      expect(type).to be_valid_parameter("foo")
      expect(type).to be_valid_parameter("baz")
    end

    it "should set any provided arguments with they keys as strings" do
      type = Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {"foo" => "bar", "baz" => "biz"})
      expect(type).to be_valid_parameter(:foo)
      expect(type).to be_valid_parameter(:baz)
    end

    it "should function if provided no arguments" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      expect(type).not_to be_valid_parameter(:foo)
    end
  end

  describe "when testing the validity of an attribute" do
    it "should return true if the parameter was typed at initialization" do
      expect(Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {"foo" => "bar"})).to be_valid_parameter("foo")
    end

    it "should return true if it is a metaparam" do
      expect(Puppet::Resource::Type.new(:hostclass, "foo")).to be_valid_parameter("require")
    end

    it "should return true if the parameter is named 'name'" do
      expect(Puppet::Resource::Type.new(:hostclass, "foo")).to be_valid_parameter("name")
    end

    it "should return false if it is not a metaparam and was not provided at initialization" do
      expect(Puppet::Resource::Type.new(:hostclass, "foo")).not_to be_valid_parameter("yayness")
    end
  end

  describe "when setting its parameters in the scope" do
    let(:parser) { Puppet::Pops::Parser::Parser.new() }

    def wrap3x(expression)
      Puppet::Parser::AST::PopsBridge::Expression.new(:value => expression.model)
    end

    def parse_expression(expr_string)
      wrap3x(parser.parse_string(expr_string))
    end

    def number_expression(number)
      wrap3x(Puppet::Pops::Model::Factory.NUMBER(number))
    end

    def variable_expression(name)
      wrap3x(Puppet::Pops::Model::Factory.QNAME(name).var())
    end

    def matchref_expression(number)
      wrap3x(Puppet::Pops::Model::Factory.NUMBER(number).var())
    end

    before(:each) do
      compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
      @scope = Puppet::Parser::Scope.new(compiler, :source => stub("source"))
      @resource = Puppet::Parser::Resource.new(:foo, "bar", :scope => @scope)
      @type = Puppet::Resource::Type.new(:definition, "foo")
      @resource.environment.known_resource_types.add @type
      Puppet.push_context(:loaders => compiler.loaders)
    end

    after(:each) do
      Puppet.pop_context
    end

    ['module_name', 'name', 'title'].each do |variable|
      it "should allow #{variable} to be evaluated as param default" do
        @type.instance_eval { @module_name = "bar" }
        @type.set_arguments :foo => variable_expression(variable)
        @type.set_resource_parameters(@resource, @scope)
        expect(@scope['foo']).to eq('bar')
      end
    end

    # this test is to clarify a crazy edge case
    # if you specify these special names as params, the resource
    # will override the special variables
    it "should allow the resource to override defaults" do
      @type.set_arguments :name => nil
      @resource[:name] = 'foobar'
      @type.set_arguments :foo => variable_expression('name')
      @type.set_resource_parameters(@resource, @scope)
      expect(@scope['foo']).to eq('foobar')
    end

    context 'referencing a variable to the left of the default expression' do
      it 'is possible when the referenced variable uses a default' do
        @type.set_arguments({
          :first => number_expression(10),
          :second => variable_expression('first'),
        })
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(10)
        expect(@scope['second']).to eq(10)
      end

      it 'is possible when the referenced variable is given a value' do
        @type.set_arguments({
          :first => number_expression(10),
          :second => variable_expression('first'),
        })
        @resource[:first] = 2
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(2)
        expect(@scope['second']).to eq(2)
      end

      it 'is possible when the referenced variable is an array produced by match function' do
        @type.set_arguments({
          :first => parse_expression("'hello'.match(/(h)(.*)/)"),
          :second => parse_expression('$first[0]'),
          :third => parse_expression('$first[1]')
        })
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(['hello', 'h', 'ello'])
        expect(@scope['second']).to eq('hello')
        expect(@scope['third']).to eq('h')
      end

      it 'fails when the referenced variable is unassigned' do
        @type.set_arguments({
          :first => nil,
          :second => variable_expression('first'),
        })
        expect { @type.set_resource_parameters(@resource, @scope) }.to raise_error(
          Puppet::Error, 'Foo[bar]: expects a value for parameter $first')
      end

      it 'does not clobber a given value' do
        @type.set_arguments({
          :first => number_expression(10),
          :second => variable_expression('first'),
        })
        @resource[:first] = 2
        @resource[:second] = 5
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(2)
        expect(@scope['second']).to eq(5)
      end
    end

    context 'referencing a variable to the right of the default expression' do
      before :each do
        @type.set_arguments({
          :first => number_expression(10),
          :second => variable_expression('third'),
          :third => number_expression(20)
        })
      end

      it 'no error is raised when no defaults are evaluated' do
        @resource[:first] = 1
        @resource[:second] = 2
        @resource[:third] = 3
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(1)
        expect(@scope['second']).to eq(2)
        expect(@scope['third']).to eq(3)
      end

      it 'no error is raised unless the referencing default expression is evaluated' do
        @resource[:second] = 2
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq(10)
        expect(@scope['second']).to eq(2)
        expect(@scope['third']).to eq(20)
      end

      it 'fails when the default expression is evaluated' do
        @resource[:first] = 1
        expect { @type.set_resource_parameters(@resource, @scope) }.to raise_error(Puppet::Error, 'Foo[bar]: default expression for $second tries to illegally access not yet evaluated $third')
      end
    end

    it 'does not allow a variable to be referenced from its own default expression' do
      @type.set_arguments({
        :first => variable_expression('first')
      })
      expect { @type.set_resource_parameters(@resource, @scope) }.to raise_error(Puppet::Error, 'Foo[bar]: default expression for $first tries to illegally access not yet evaluated $first')
    end

    context 'when using match scope' do
      it '$n evaluates to undef at the top level' do
        @type.set_arguments({
          :first => matchref_expression('0'),
          :second => matchref_expression('1'),
        })
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope).not_to include('first')
        expect(@scope).not_to include('second')
      end

      it 'a match scope to the left of a parameter is not visible to it' do
        @type.set_arguments({
          :first => parse_expression("['hello' =~ /(h)(.*)/, $1, $2]"),
          :second => matchref_expression('1'),
        })
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq([true, 'h', 'ello'])
        expect(@scope['second']).to be_nil
      end

      it 'match scopes nests per parameter' do
        @type.set_arguments({
          :first => parse_expression("['hi' =~ /(h)(.*)/, $1, if 'foo' =~ /f(oo)/ { $1 }, $1, $2]"),
          :second => matchref_expression('0'),
        })
        @type.set_resource_parameters(@resource, @scope)

        expect(@scope['first']).to eq([true, 'h', 'oo', 'h', 'i'])
        expect(@scope['second']).to be_nil
      end
    end

    it "should set each of the resource's parameters as variables in the scope" do
      @type.set_arguments :foo => nil, :boo => nil
      @resource[:foo] = "bar"
      @resource[:boo] = "baz"

      @type.set_resource_parameters(@resource, @scope)

      expect(@scope['foo']).to eq("bar")
      expect(@scope['boo']).to eq("baz")
    end

    it "should set the variables as strings" do
      @type.set_arguments :foo => nil
      @resource[:foo] = "bar"

      @type.set_resource_parameters(@resource, @scope)

      expect(@scope['foo']).to eq("bar")
    end

    it "should fail if any of the resource's parameters are not valid attributes" do
      @type.set_arguments :foo => nil
      @resource[:boo] = "baz"

      expect { @type.set_resource_parameters(@resource, @scope) }.to raise_error(Puppet::ParseError)
    end

    it "should evaluate and set its default values as variables for parameters not provided by the resource" do
      @type.set_arguments :foo => Puppet::Parser::AST::Leaf.new(:value => "something")
      @type.set_resource_parameters(@resource, @scope)
      expect(@scope['foo']).to eq("something")
    end

    it "should set all default values as parameters in the resource" do
      @type.set_arguments :foo => Puppet::Parser::AST::Leaf.new(:value => "something")

      @type.set_resource_parameters(@resource, @scope)

      expect(@resource[:foo]).to eq("something")
    end

    it "should fail if the resource does not provide a value for a required argument" do
      @type.set_arguments :foo => nil

      expect { @type.set_resource_parameters(@resource, @scope) }.to raise_error(Puppet::ParseError)
    end

    it "should set the resource's title as a variable if not otherwise provided" do
      @type.set_resource_parameters(@resource, @scope)

      expect(@scope['title']).to eq("bar")
    end

    it "should set the resource's name as a variable if not otherwise provided" do
      @type.set_resource_parameters(@resource, @scope)

      expect(@scope['name']).to eq("bar")
    end

    it "should set its module name in the scope if available" do
      @type.instance_eval { @module_name = "mymod" }

      @type.set_resource_parameters(@resource, @scope)

      expect(@scope["module_name"]).to eq("mymod")
    end

    it "should set its caller module name in the scope if available" do
      @scope.expects(:parent_module_name).returns "mycaller"

      @type.set_resource_parameters(@resource, @scope)

      expect(@scope["caller_module_name"]).to eq("mycaller")
    end
  end

  describe "when describing and managing parent classes" do
    before do
      environment = Puppet::Node::Environment.create(:testing, [])
      @krt = environment.known_resource_types
      @parent = Puppet::Resource::Type.new(:hostclass, "bar")
      @krt.add @parent

      @child = Puppet::Resource::Type.new(:hostclass, "foo", :parent => "bar")
      @krt.add @child

      @scope = Puppet::Parser::Scope.new(Puppet::Parser::Compiler.new(Puppet::Node.new("foo", :environment => environment)))
    end

    it "should be able to define a parent" do
      Puppet::Resource::Type.new(:hostclass, "foo", :parent => "bar")
    end

    it "should use the code collection to find the parent resource type" do
      expect(@child.parent_type(@scope)).to equal(@parent)
    end

    it "should be able to find parent nodes" do
      parent = Puppet::Resource::Type.new(:node, "bar")
      @krt.add parent
      child = Puppet::Resource::Type.new(:node, "foo", :parent => "bar")
      @krt.add child

      expect(child.parent_type(@scope)).to equal(parent)
    end

    it "should cache a reference to the parent type" do
      @krt.stubs(:hostclass).with("foo::bar").returns nil
      @krt.expects(:hostclass).with("bar").once.returns @parent
      @child.parent_type(@scope)
      @child.parent_type
    end

    it "should correctly state when it is another type's child" do
      @child.parent_type(@scope)
      expect(@child).to be_child_of(@parent)
    end

    it "should be considered the child of a parent's parent" do
      @grandchild = Puppet::Resource::Type.new(:hostclass, "baz", :parent => "foo")
      @krt.add @grandchild

      @child.parent_type(@scope)
      @grandchild.parent_type(@scope)

      expect(@grandchild).to be_child_of(@parent)
    end

    it "should correctly state when it is not another type's child" do
      @notchild = Puppet::Resource::Type.new(:hostclass, "baz")
      @krt.add @notchild

      expect(@notchild).not_to be_child_of(@parent)
    end
  end

  describe "when evaluating its code" do
    before do
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
      @scope = Puppet::Parser::Scope.new @compiler
      @resource = Puppet::Parser::Resource.new(:class, "foo", :scope => @scope)

      # This is so the internal resource lookup works, yo.
      @compiler.catalog.add_resource @resource

      @type = Puppet::Resource::Type.new(:hostclass, "foo")
      @resource.environment.known_resource_types.add @type
    end

    it "should add node regex captures to its scope" do
      @type = Puppet::Resource::Type.new(:node, /f(\w)o(.*)$/)
      match = @type.match('foo')

      code = stub 'code'
      @type.stubs(:code).returns code

      subscope = stub 'subscope', :compiler => @compiler
      @scope.expects(:newscope).with(:source => @type, :resource => @resource).returns subscope

      subscope.expects(:with_guarded_scope).yields
      subscope.expects(:ephemeral_from).with(match, nil, nil).returns subscope
      code.expects(:safeevaluate).with(subscope)

      # Just to keep the stub quiet about intermediate calls
      @type.expects(:set_resource_parameters).with(@resource, subscope)

      @type.evaluate_code(@resource)
    end

    it "should add hostclass names to the classes list" do
      @type.evaluate_code(@resource)
      expect(@compiler.catalog.classes).to be_include("foo")
    end

    it "should not add defined resource names to the classes list" do
      @type = Puppet::Resource::Type.new(:definition, "foo")
      @type.evaluate_code(@resource)
      expect(@compiler.catalog.classes).not_to be_include("foo")
    end

    it "should set all of its parameters in a subscope" do
      subscope = stub 'subscope', :compiler => @compiler
      @scope.expects(:newscope).with(:source => @type, :resource => @resource).returns subscope
      @type.expects(:set_resource_parameters).with(@resource, subscope)

      @type.evaluate_code(@resource)
    end

    it "should not create a subscope for the :main class" do
      @resource.stubs(:title).returns(:main)
      @type.expects(:subscope).never
      @type.expects(:set_resource_parameters).with(@resource, @scope)

      @type.evaluate_code(@resource)
    end

    it "should store the class scope" do
      @type.evaluate_code(@resource)
      expect(@scope.class_scope(@type)).to be_instance_of(@scope.class)
    end

    it "should still create a scope but not store it if the type is a definition" do
      @type = Puppet::Resource::Type.new(:definition, "foo")
      @type.evaluate_code(@resource)
      expect(@scope.class_scope(@type)).to be_nil
    end

    it "should evaluate the AST code if any is provided" do
      code = stub 'code'
      @type.stubs(:code).returns code
      code.expects(:safeevaluate).with kind_of(Puppet::Parser::Scope)

      @type.evaluate_code(@resource)
    end

    it "should noop if there is no code" do
      @type.expects(:code).returns nil

      @type.evaluate_code(@resource)
    end

    describe "and it has a parent class" do
      before do
        @parent_type = Puppet::Resource::Type.new(:hostclass, "parent")
        @type.parent = "parent"
        @parent_resource = Puppet::Parser::Resource.new(:class, "parent", :scope => @scope)

        @compiler.add_resource @scope, @parent_resource

        @type.resource_type_collection = @scope.environment.known_resource_types
        @type.resource_type_collection.add @parent_type
      end

      it "should evaluate the parent's resource" do
        @type.parent_type(@scope)

        @type.evaluate_code(@resource)

        expect(@scope.class_scope(@parent_type)).not_to be_nil
      end

      it "should not evaluate the parent's resource if it has already been evaluated" do
        @parent_resource.evaluate

        @type.parent_type(@scope)

        @parent_resource.expects(:evaluate).never

        @type.evaluate_code(@resource)
      end

      it "should use the parent's scope as its base scope" do
        @type.parent_type(@scope)

        @type.evaluate_code(@resource)

        expect(@scope.class_scope(@type).parent.object_id).to eq(@scope.class_scope(@parent_type).object_id)
      end
    end

    describe "and it has a parent node" do
      before do
        @type = Puppet::Resource::Type.new(:node, "foo")
        @parent_type = Puppet::Resource::Type.new(:node, "parent")
        @type.parent = "parent"
        @parent_resource = Puppet::Parser::Resource.new(:node, "parent", :scope => @scope)

        @compiler.add_resource @scope, @parent_resource

        @type.resource_type_collection = @scope.environment.known_resource_types
        @type.resource_type_collection.add(@parent_type)
      end

      it "should evaluate the parent's resource" do
        @type.parent_type(@scope)

        @type.evaluate_code(@resource)

        expect(@scope.class_scope(@parent_type)).not_to be_nil
      end

      it "should not evaluate the parent's resource if it has already been evaluated" do
        @parent_resource.evaluate

        @type.parent_type(@scope)

        @parent_resource.expects(:evaluate).never

        @type.evaluate_code(@resource)
      end

      it "should use the parent's scope as its base scope" do
        @type.parent_type(@scope)

        @type.evaluate_code(@resource)

        expect(@scope.class_scope(@type).parent.object_id).to eq(@scope.class_scope(@parent_type).object_id)
      end
    end
  end

  describe "when creating a resource" do
    before do
      env = Puppet::Node::Environment.create('env', [])
      @node = Puppet::Node.new("foo", :environment => env)
      @compiler = Puppet::Parser::Compiler.new(@node)
      @scope = Puppet::Parser::Scope.new(@compiler)

      @top = Puppet::Resource::Type.new :hostclass, "top"
      @middle = Puppet::Resource::Type.new :hostclass, "middle", :parent => "top"

      @code = env.known_resource_types
      @code.add @top
      @code.add @middle
    end

    it "should create a resource instance" do
      expect(@top.ensure_in_catalog(@scope)).to be_instance_of(Puppet::Parser::Resource)
    end

    it "should set its resource type to 'class' when it is a hostclass" do
      expect(Puppet::Resource::Type.new(:hostclass, "top").ensure_in_catalog(@scope).type).to eq("Class")
    end

    it "should set its resource type to 'node' when it is a node" do
      expect(Puppet::Resource::Type.new(:node, "top").ensure_in_catalog(@scope).type).to eq("Node")
    end

    it "should fail when it is a definition" do
      expect { Puppet::Resource::Type.new(:definition, "top").ensure_in_catalog(@scope) }.to raise_error(ArgumentError)
    end

    it "should add the created resource to the scope's catalog" do
      @top.ensure_in_catalog(@scope)

      expect(@compiler.catalog.resource(:class, "top")).to be_instance_of(Puppet::Parser::Resource)
    end

    it "should add specified parameters to the resource" do
      @top.ensure_in_catalog(@scope, {'one'=>'1', 'two'=>'2'})
      expect(@compiler.catalog.resource(:class, "top")['one']).to eq('1')
      expect(@compiler.catalog.resource(:class, "top")['two']).to eq('2')
    end

    it "should not require params for a param class" do
      @top.ensure_in_catalog(@scope, {})
      expect(@compiler.catalog.resource(:class, "top")).to be_instance_of(Puppet::Parser::Resource)
    end

    it "should evaluate the parent class if one exists" do
      @middle.ensure_in_catalog(@scope)

      expect(@compiler.catalog.resource(:class, "top")).to be_instance_of(Puppet::Parser::Resource)
    end

    it "should evaluate the parent class if one exists" do
      @middle.ensure_in_catalog(@scope, {})

      expect(@compiler.catalog.resource(:class, "top")).to be_instance_of(Puppet::Parser::Resource)
    end

    it "should fail if you try to create duplicate class resources" do
      othertop = Puppet::Parser::Resource.new(:class, 'top',:source => @source, :scope => @scope )
      # add the same class resource to the catalog
      @compiler.catalog.add_resource(othertop)
      expect { @top.ensure_in_catalog(@scope, {}) }.to raise_error(Puppet::Resource::Catalog::DuplicateResourceError)
    end

    it "should fail to evaluate if a parent class is defined but cannot be found" do
      othertop = Puppet::Resource::Type.new :hostclass, "something", :parent => "yay"
      @code.add othertop
      expect { othertop.ensure_in_catalog(@scope) }.to raise_error(Puppet::ParseError)
    end

    it "should not create a new resource if one already exists" do
      @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
      @compiler.catalog.expects(:add_resource).never
      @top.ensure_in_catalog(@scope)
    end

    it "should return the existing resource when not creating a new one" do
      @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
      @compiler.catalog.expects(:add_resource).never
      expect(@top.ensure_in_catalog(@scope)).to eq("something")
    end

    it "should not create a new parent resource if one already exists and it has a parent class" do
      @top.ensure_in_catalog(@scope)

      top_resource = @compiler.catalog.resource(:class, "top")

      @middle.ensure_in_catalog(@scope)

      expect(@compiler.catalog.resource(:class, "top")).to equal(top_resource)
    end

    # #795 - tag before evaluation.
    it "should tag the catalog with the resource tags when it is evaluated" do
      @middle.ensure_in_catalog(@scope)

      expect(@compiler.catalog).to be_tagged("middle")
    end

    it "should tag the catalog with the parent class tags when it is evaluated" do
      @middle.ensure_in_catalog(@scope)

      expect(@compiler.catalog).to be_tagged("top")
    end
  end

  describe "when merging code from another instance" do
    def code(str)
      Puppet::Pops::Model::Factory.literal(str)
    end

    it "should fail unless it is a class" do
      expect { Puppet::Resource::Type.new(:node, "bar").merge("foo") }.to raise_error(Puppet::Error)
    end

    it "should fail unless the source instance is a class" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:node, "foo")
      expect { dest.merge(source) }.to raise_error(Puppet::Error)
    end

    it "should fail if both classes have different parent classes" do
      code = Puppet::Resource::TypeCollection.new("env")
      {"a" => "b", "c" => "d"}.each do |parent, child|
        code.add Puppet::Resource::Type.new(:hostclass, parent)
        code.add Puppet::Resource::Type.new(:hostclass, child, :parent => parent)
      end
      expect { code.hostclass("b").merge(code.hostclass("d")) }.to raise_error(Puppet::Error)
    end

    context 'when "freeze_main" is enabled and a merge is done into the main class' do
      it "an error is raised if there is something other than definitions in the merged class" do
        Puppet.settings[:freeze_main] = true
        code = Puppet::Resource::TypeCollection.new("env")
        code.add Puppet::Resource::Type.new(:hostclass, "")
        other = Puppet::Resource::Type.new(:hostclass, "")
        mock = stub
        mock.expects(:is_definitions_only?).returns(false)
        other.expects(:code).returns(mock)
        expect { code.hostclass("").merge(other) }.to raise_error(Puppet::Error)
      end

      it "an error is not raised if the merged class contains nothing but definitions" do
        Puppet.settings[:freeze_main] = true
        code = Puppet::Resource::TypeCollection.new("env")
        code.add Puppet::Resource::Type.new(:hostclass, "")
        other = Puppet::Resource::Type.new(:hostclass, "")
        mock = stub
        mock.expects(:is_definitions_only?).returns(true)
        other.expects(:code).at_least_once.returns(mock)
        expect { code.hostclass("").merge(other) }.not_to raise_error
      end
    end

    it "should copy the other class's parent if it has not parent" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")

      Puppet::Resource::Type.new(:hostclass, "parent")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :parent => "parent")
      dest.merge(source)

      expect(dest.parent).to eq("parent")
    end

    it "should copy the other class's documentation as its docs if it has no docs" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "yayness")
      dest.merge(source)

      expect(dest.doc).to eq("yayness")
    end

    it "should append the other class's docs to its docs if it has any" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar", :doc => "fooness")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "yayness")
      dest.merge(source)

      expect(dest.doc).to eq("foonessyayness")
    end

    it "should set the other class's code as its code if it has none" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :code => code("bar").model)

      dest.merge(source)

      expect(dest.code.value).to eq("bar")
    end

    it "should append the other class's code to its code if it has any" do
      # PUP-3274, the code merging at the top still uses AST::BlockExpression
      # But does not do mutating changes to code blocks, instead a new block is created
      # with references to the two original blocks.
      # TODO: fix this when the code merging is changed at the very top in 4x.
      #
      dcode = Puppet::Parser::AST::BlockExpression.new(:children => [code("dest")])
      dest = Puppet::Resource::Type.new(:hostclass, "bar", :code => dcode)

      scode = Puppet::Parser::AST::BlockExpression.new(:children => [code("source")])
      source = Puppet::Resource::Type.new(:hostclass, "foo", :code => scode)

      dest.merge(source)
      expect(dest.code.children.map { |c| c.value }).to eq(%w{dest source})
    end
  end
end
