#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Collection do
  before :each do
    @mytype = Puppet::Resource::Type.new(:definition, "mytype")
    @environment = Puppet::Node::Environment.create(:testing, [])
    @environment.known_resource_types.add @mytype

    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foonode", :environment => @environment))
    @scope = Puppet::Parser::Scope.new(@compiler)

    @overrides = stub_everything 'overrides'
    @overrides.stubs(:is_a?).with(Puppet::Parser::AST).returns(true)
  end

  it "should evaluate its query" do
    query = mock 'query'
    collection = Puppet::Parser::AST::Collection.new :query => query, :form => :virtual
    collection.type = 'mytype'

    query.expects(:safeevaluate).with(@scope)

    collection.evaluate(@scope)
  end

  it "should instantiate a Collector for this type" do
    collection = Puppet::Parser::AST::Collection.new :form => :virtual, :type => "test"
    @test_type = Puppet::Resource::Type.new(:definition, "test")
    @environment.known_resource_types.add @test_type

    Puppet::Parser::Collector.expects(:new).with(@scope, "test", nil, nil, :virtual)

    collection.evaluate(@scope)
  end

  it "should tell the compiler about this collector" do
    collection = Puppet::Parser::AST::Collection.new :form => :virtual, :type => "mytype"
    Puppet::Parser::Collector.stubs(:new).returns("whatever")

    @compiler.expects(:add_collection).with("whatever")

    collection.evaluate(@scope)
  end

  it "should evaluate overriden paramaters" do
    collector = stub_everything 'collector'
    collection = Puppet::Parser::AST::Collection.new :form => :virtual, :type => "mytype", :override => @overrides
    Puppet::Parser::Collector.stubs(:new).returns(collector)

    @overrides.expects(:safeevaluate).with(@scope)

    collection.evaluate(@scope)
  end

  it "should tell the collector about overrides" do
    collector = mock 'collector'
    collection = Puppet::Parser::AST::Collection.new :form => :virtual, :type => "mytype", :override => @overrides
    Puppet::Parser::Collector.stubs(:new).returns(collector)

    collector.expects(:add_override)

    collection.evaluate(@scope)
  end

  it "should fail when evaluating undefined resource types" do
    collection = Puppet::Parser::AST::Collection.new :form => :virtual, :type => "bogus"
    lambda { collection.evaluate(@scope) }.should raise_error "Resource type bogus doesn't exist"
  end
end
