#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/json'

describe Puppet::Node do
  include JSONMatchers

  let(:environment) { Puppet::Node::Environment.create(:bar, []) }
  let(:env_loader) { Puppet::Environments::Static.new(environment) }

  it "should register its document type as Node" do
    PSON.registered_document_types["Node"].should equal(Puppet::Node)
  end

  describe "when managing its environment" do
    it "should use any set environment" do
      Puppet.override(:environments => env_loader) do
        Puppet::Node.new("foo", :environment => "bar").environment.should == environment
      end
    end

    it "should support providing an actual environment instance" do
      Puppet::Node.new("foo", :environment => environment).environment.name.should == :bar
    end

    it "should determine its environment from its parameters if no environment is set" do
      Puppet.override(:environments => env_loader) do
        Puppet::Node.new("foo", :parameters => {"environment" => :bar}).environment.should == environment
      end
    end

    it "should use the configured environment if no environment is provided" do
      Puppet[:environment] = environment.name.to_s

      Puppet.override(:environments => env_loader) do
        Puppet::Node.new("foo").environment.should == environment
      end
    end

    it "should allow the environment to be set after initialization" do
      node = Puppet::Node.new("foo")
      node.environment = :bar
      node.environment.name.should == :bar
    end

    it "should allow its environment to be set by parameters after initialization" do
      node = Puppet::Node.new("foo")
      node.parameters["environment"] = :bar
      node.environment.name.should == :bar
    end
  end

  it "can survive a round-trip through YAML" do
    facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
    node = Puppet::Node.new("hello",
                            :environment => 'kjhgrg',
                            :classes => ['erth', 'aiu'],
                            :parameters => {"hostname"=>"food"}
                           )
    new_node = Puppet::Node.convert_from('yaml', node.render('yaml'))
    new_node.environment.should == node.environment
    new_node.parameters.should == node.parameters
    new_node.classes.should == node.classes
    new_node.name.should == node.name
  end

  it "can round-trip through pson" do
    facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
    node = Puppet::Node.new("hello",
                            :environment => 'kjhgrg',
                            :classes => ['erth', 'aiu'],
                            :parameters => {"hostname"=>"food"}
                           )
    new_node = Puppet::Node.convert_from('pson', node.render('pson'))
    new_node.environment.should == node.environment
    new_node.parameters.should == node.parameters
    new_node.classes.should == node.classes
    new_node.name.should == node.name
  end

  it "validates against the node json schema", :unless => Puppet.features.microsoft_windows? do
    facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
    node = Puppet::Node.new("hello",
                            :environment => 'kjhgrg',
                            :classes => ['erth', 'aiu'],
                            :parameters => {"hostname"=>"food"}
                           )
    expect(node.to_pson).to validate_against('api/schemas/node.json')
  end

  it "when missing optional parameters validates against the node json schema", :unless => Puppet.features.microsoft_windows? do
    facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
    node = Puppet::Node.new("hello",
                            :environment => 'kjhgrg'
                           )
    expect(node.to_pson).to validate_against('api/schemas/node.json')
  end

  describe "when converting to json" do
    before do
      @node = Puppet::Node.new("mynode")
    end

    it "should provide its name" do
      @node.should set_json_attribute('name').to("mynode")
    end

    it "should produce a hash with the document_type set to 'Node'" do
      @node.should set_json_document_type_to("Node")
    end

    it "should include the classes if set" do
      @node.classes = %w{a b c}
      @node.should set_json_attribute("classes").to(%w{a b c})
    end

    it "should not include the classes if there are none" do
      @node.should_not set_json_attribute('classes')
    end

    it "should include parameters if set" do
      @node.parameters = {"a" => "b", "c" => "d"}
      @node.should set_json_attribute('parameters').to({"a" => "b", "c" => "d"})
    end

    it "should not include the parameters if there are none" do
      @node.should_not set_json_attribute('parameters')
    end

    it "should include the environment" do
      @node.environment = "production"
      @node.should set_json_attribute('environment').to('production')
    end
  end

  describe "when converting from json" do
    before do
      @node = Puppet::Node.new("mynode")
      @format = Puppet::Network::FormatHandler.format('pson')
    end

    def from_json(json)
      @format.intern(Puppet::Node, json)
    end

    it "should set its name" do
      Puppet::Node.should read_json_attribute('name').from(@node.to_pson).as("mynode")
    end

    it "should include the classes if set" do
      @node.classes = %w{a b c}
      Puppet::Node.should read_json_attribute('classes').from(@node.to_pson).as(%w{a b c})
    end

    it "should include parameters if set" do
      @node.parameters = {"a" => "b", "c" => "d"}
      Puppet::Node.should read_json_attribute('parameters').from(@node.to_pson).as({"a" => "b", "c" => "d"})
    end

    it "deserializes environment to environment_name as a string" do
      @node.environment = environment
      Puppet::Node.should read_json_attribute('environment_name').from(@node.to_pson).as('bar')
    end
  end
end

describe Puppet::Node, "when initializing" do
  before do
    @node = Puppet::Node.new("testnode")
  end

  it "should set the node name" do
    @node.name.should == "testnode"
  end

  it "should not allow nil node names" do
    proc { Puppet::Node.new(nil) }.should raise_error(ArgumentError)
  end

  it "should default to an empty parameter hash" do
    @node.parameters.should == {}
  end

  it "should default to an empty class array" do
    @node.classes.should == []
  end

  it "should note its creation time" do
    @node.time.should be_instance_of(Time)
  end

  it "should accept parameters passed in during initialization" do
    params = {"a" => "b"}
    @node = Puppet::Node.new("testing", :parameters => params)
    @node.parameters.should == params
  end

  it "should accept classes passed in during initialization" do
    classes = %w{one two}
    @node = Puppet::Node.new("testing", :classes => classes)
    @node.classes.should == classes
  end

  it "should always return classes as an array" do
    @node = Puppet::Node.new("testing", :classes => "myclass")
    @node.classes.should == ["myclass"]
  end
end

describe Puppet::Node, "when merging facts" do
  before do
    @node = Puppet::Node.new("testnode")
    Puppet::Node::Facts.indirection.stubs(:find).with(@node.name, instance_of(Hash)).returns(Puppet::Node::Facts.new(@node.name, "one" => "c", "two" => "b"))
  end

  it "should fail intelligently if it cannot find facts" do
    Puppet::Node::Facts.indirection.expects(:find).with(@node.name, instance_of(Hash)).raises "foo"
    lambda { @node.fact_merge }.should raise_error(Puppet::Error)
  end

  it "should prefer parameters already set on the node over facts from the node" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    @node.parameters["one"].should == "a"
  end

  it "should add passed parameters to the parameter list" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    @node.parameters["two"].should == "b"
  end

  it "should accept arbitrary parameters to merge into its parameters" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.merge "two" => "three"
    @node.parameters["two"].should == "three"
  end

  it "should add the environment to the list of parameters" do
    Puppet[:environment] = "one"
    @node = Puppet::Node.new("testnode", :environment => "one")
    @node.merge "two" => "three"
    @node.parameters["environment"].should == "one"
  end

  it "should not set the environment if it is already set in the parameters" do
    Puppet[:environment] = "one"
    @node = Puppet::Node.new("testnode", :environment => "one")
    @node.merge "environment" => "two"
    @node.parameters["environment"].should == "two"
  end
end

describe Puppet::Node, "when indirecting" do
  it "should default to the 'plain' node terminus" do
    Puppet::Node.indirection.reset_terminus_class

    Puppet::Node.indirection.terminus_class.should == :plain
  end
end

describe Puppet::Node, "when generating the list of names to search through" do
  before do
    @node = Puppet::Node.new("foo.domain.com", :parameters => {"hostname" => "yay", "domain" => "domain.com"})
  end

  it "should return an array of names" do
    @node.names.should be_instance_of(Array)
  end

  describe "and the node name is fully qualified" do
    it "should contain an entry for each part of the node name" do
      @node.names.should be_include("foo.domain.com")
      @node.names.should be_include("foo.domain")
      @node.names.should be_include("foo")
    end
  end

  it "should include the node's fqdn" do
    @node.names.should be_include("yay.domain.com")
  end

  it "should combine and include the node's hostname and domain if no fqdn is available" do
    @node.names.should be_include("yay.domain.com")
  end

  it "should contain an entry for each name available by stripping a segment of the fqdn" do
    @node.parameters["fqdn"] = "foo.deep.sub.domain.com"
    @node.names.should be_include("foo.deep.sub.domain")
    @node.names.should be_include("foo.deep.sub")
  end

  describe "and :node_name is set to 'cert'" do
    before do
      Puppet[:strict_hostname_checking] = false
      Puppet[:node_name] = "cert"
    end

    it "should use the passed-in key as the first value" do
      @node.names[0].should == "foo.domain.com"
    end

    describe "and strict hostname checking is enabled" do
      it "should only use the passed-in key" do
        Puppet[:strict_hostname_checking] = true
        @node.names.should == ["foo.domain.com"]
      end
    end
  end

  describe "and :node_name is set to 'facter'" do
    before do
      Puppet[:strict_hostname_checking] = false
      Puppet[:node_name] = "facter"
    end

    it "should use the node's 'hostname' fact as the first value" do
      @node.names[0].should == "yay"
    end
  end
end
