#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Resource do
  ast = Puppet::Parser::AST

  describe "for builtin types" do
    before :each do
      @title = Puppet::Parser::AST::String.new(:value => "mytitle")
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
      @scope = Puppet::Parser::Scope.new(@compiler)
      @scope.stubs(:resource).returns(stub_everything)
      @instance = ast::ResourceInstance.new(:title => @title, :parameters => ast::ASTArray.new(:children => []))
      @resource = ast::Resource.new(:type => "file", :instances => ast::ASTArray.new(:children => [@instance]))
      @resource.stubs(:qualified_type).returns("Resource")
    end

    it "should evaluate all its parameters" do
      param = stub 'param'
      param.expects(:safeevaluate).with(@scope).returns Puppet::Parser::Resource::Param.new(:name => "myparam", :value => "myvalue", :source => stub("source"))
      @instance.stubs(:parameters).returns [param]

      @resource.evaluate(@scope)
    end

    it "should evaluate its title" do
      @resource.evaluate(@scope)[0].title.should == "mytitle"
    end

    it "should flatten the titles array" do
      titles = []
      %w{one two}.each do |title|
        titles << Puppet::Parser::AST::String.new(:value => title)
      end

      array = Puppet::Parser::AST::ASTArray.new(:children => titles)

      @instance.title = array
      result = @resource.evaluate(@scope).collect { |r| r.title }
      result.should be_include("one")
      result.should be_include("two")
    end

    it "should create and return one resource objects per title" do
      titles = []
      %w{one two}.each do |title|
        titles << Puppet::Parser::AST::String.new(:value => title)
      end

      array = Puppet::Parser::AST::ASTArray.new(:children => titles)

      @instance.title = array
      result = @resource.evaluate(@scope).collect { |r| r.title }
      result.should be_include("one")
      result.should be_include("two")
    end

    it "should implicitly iterate over instances" do
      new_title = Puppet::Parser::AST::String.new(:value => "other_title")
      new_instance = ast::ResourceInstance.new(:title => new_title, :parameters => ast::ASTArray.new(:children => []))
      @resource.instances.push(new_instance)
      @resource.evaluate(@scope).collect { |r| r.title }.should == ["mytitle", "other_title"]
    end

    it "should handover resources to the compiler" do
      titles = []
      %w{one two}.each do |title|
        titles << Puppet::Parser::AST::String.new(:value => title)
      end

      array = Puppet::Parser::AST::ASTArray.new(:children => titles)

      @instance.title = array
      result = @resource.evaluate(@scope)

      result.each do |res|
        @compiler.catalog.resource(res.ref).should be_instance_of(Puppet::Parser::Resource)
      end
    end

    it "should generate virtual resources if it is virtual" do
      @resource.virtual = true

      result = @resource.evaluate(@scope)
      result[0].should be_virtual
    end

    it "should generate virtual and exported resources if it is exported" do
      @resource.exported = true

      result = @resource.evaluate(@scope)
      result[0].should be_virtual
      result[0].should be_exported
    end

    # Related to #806, make sure resources always look up the full path to the resource.
    describe "when generating qualified resources" do
      before do
        @scope = Puppet::Parser::Scope.new Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
        @parser = Puppet::Parser::Parser.new(@scope.environment)
        ["one", "one::two", "three"].each do |name|
          @parser.environment.known_resource_types.add(Puppet::Resource::Type.new(:definition, name, {}))
        end
        @twoscope = @scope.newscope(:namespace => "one")
        @twoscope.resource = @scope.resource
      end

      def resource(type, params = nil)
        params ||= Puppet::Parser::AST::ASTArray.new(:children => [])
        instance = Puppet::Parser::AST::ResourceInstance.new(
                                                             :title => Puppet::Parser::AST::String.new(:value => "myresource"), :parameters => params)
        Puppet::Parser::AST::Resource.new(:type => type,
                                          :instances => Puppet::Parser::AST::ASTArray.new(:children => [instance]))
      end

      it "should be able to generate resources with fully qualified type information" do
        resource("two").evaluate(@twoscope)[0].type.should == "One::Two"
      end

      it "should be able to generate resources with unqualified type information" do
        resource("one").evaluate(@twoscope)[0].type.should == "One"
      end

      it "should correctly generate resources that can look up builtin types" do
        resource("file").evaluate(@twoscope)[0].type.should == "File"
      end

      it "should correctly generate resources that can look up defined classes by title" do
        @scope.known_resource_types.add_hostclass Puppet::Resource::Type.new(:hostclass, "Myresource", {})
        @scope.compiler.stubs(:evaluate_classes)
        res = resource("class").evaluate(@twoscope)[0]
        res.type.should == "Class"
        res.title.should == "Myresource"
      end

      it "should evaluate parameterized classes when they are instantiated" do
        @scope.known_resource_types.add_hostclass Puppet::Resource::Type.new(:hostclass, "Myresource", {})
        @scope.compiler.expects(:evaluate_classes).with(['myresource'],@twoscope,false,true)
        resource("class").evaluate(@twoscope)[0]
      end

      it "should fail for resource types that do not exist" do
        lambda { resource("nosuchtype").evaluate(@twoscope) }.should raise_error(Puppet::ParseError)
      end
    end
  end

  describe "for class resources" do
    before do
      @title = Puppet::Parser::AST::String.new(:value => "classname")
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
      @scope = Puppet::Parser::Scope.new(@compiler)
      @scope.stubs(:resource).returns(stub_everything)
      @instance = ast::ResourceInstance.new(:title => @title, :parameters => ast::ASTArray.new(:children => []))
      @resource = ast::Resource.new(:type => "Class", :instances => ast::ASTArray.new(:children => [@instance]))
      @resource.stubs(:qualified_type).returns("Resource")
      @type = Puppet::Resource::Type.new(:hostclass, "classname")
      @compiler.known_resource_types.add(@type)
    end

    it "should instantiate the class" do
      @compiler.stubs(:evaluate_classes)
      result = @resource.evaluate(@scope)
      result.length.should == 1
      result.first.ref.should == "Class[Classname]"
      @compiler.catalog.resource("Class[Classname]").should equal(result.first)
    end

    it "should cause its parent to be evaluated" do
      parent_type = Puppet::Resource::Type.new(:hostclass, "parentname")
      @compiler.stubs(:evaluate_classes)
      @compiler.known_resource_types.add(parent_type)
      @type.parent = "parentname"
      result = @resource.evaluate(@scope)
      result.length.should == 1
      result.first.ref.should == "Class[Classname]"
      @compiler.catalog.resource("Class[Classname]").should equal(result.first)
      @compiler.catalog.resource("Class[Parentname]").should be_instance_of(Puppet::Parser::Resource)
    end

  end

end
