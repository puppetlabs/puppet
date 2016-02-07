#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/json'

describe Puppet::Node do
  include JSONMatchers

  let(:environment) { Puppet::Node::Environment.create(:bar, []) }
  let(:env_loader) { Puppet::Environments::Static.new(environment) }

  describe "when managing its environment" do

    it "provides an environment instance" do
      expect(Puppet::Node.new("foo", :environment => environment).environment.name).to eq(:bar)
    end

    context "present in a loader" do
      around do |example|
        Puppet.override(:environments => env_loader) do
          example.run
        end
      end

      it "uses any set environment" do
        expect(Puppet::Node.new("foo", :environment => "bar").environment).to eq(environment)
      end

      it "determines its environment from its parameters if no environment is set" do
        expect(Puppet::Node.new("foo", :parameters => {"environment" => :bar}).environment).to eq(environment)
      end

      it "uses the configured environment if no environment is provided" do
        Puppet[:environment] = environment.name.to_s
        expect(Puppet::Node.new("foo").environment).to eq(environment)
      end

      it "allows the environment to be set after initialization" do
        node = Puppet::Node.new("foo")
        node.environment = :bar
        expect(node.environment.name).to eq(:bar)
      end

      it "allows its environment to be set by parameters after initialization" do
        node = Puppet::Node.new("foo")
        node.parameters["environment"] = :bar
        expect(node.environment.name).to eq(:bar)
      end
    end
  end

  describe "serialization" do
    around do |example|
      Puppet.override(:environments => env_loader) do
        example.run
      end
    end

    it "can round-trip through pson" do
      facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
      node = Puppet::Node.new("hello",
                              :environment => 'bar',
                              :classes => ['erth', 'aiu'],
                              :parameters => {"hostname"=>"food"}
                             )
      new_node = Puppet::Node.convert_from('pson', node.render('pson'))
      expect(new_node.environment).to eq(node.environment)
      expect(new_node.parameters).to eq(node.parameters)
      expect(new_node.classes).to eq(node.classes)
      expect(new_node.name).to eq(node.name)
    end

    it "validates against the node json schema", :unless => Puppet.features.microsoft_windows? do
      facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
      node = Puppet::Node.new("hello",
                              :environment => 'bar',
                              :classes => ['erth', 'aiu'],
                              :parameters => {"hostname"=>"food"}
                             )
      expect(node.to_pson).to validate_against('api/schemas/node.json')
    end

    it "when missing optional parameters validates against the node json schema", :unless => Puppet.features.microsoft_windows? do
      facts = Puppet::Node::Facts.new("hello", "one" => "c", "two" => "b")
      node = Puppet::Node.new("hello",
                              :environment => 'bar'
                             )
      expect(node.to_pson).to validate_against('api/schemas/node.json')
    end

    it "should allow its environment parameter to be set by attribute after initialization" do
      node = Puppet::Node.new("foo", { :parameters => { 'environment' => :foo } })
      node.environment_name = :foo
      node.environment = :bar
      expect(node.environment_name).to eq(:bar)
      expect(node.parameters['environment']).to eq('bar')
    end
  end

  describe "when serializing using yaml" do
    before do
      @node = Puppet::Node.new("mynode")
    end

    it "a node can roundtrip" do
      expect(YAML.load(@node.to_yaml).name).to eql("mynode")
    end

    it "limits the serialization of environment to be just the name" do
      # it is something like 138 when serializing everything in a default environment
      expect(@node.to_yaml.size).to be < 70
    end
  end

  describe "when serializing using yaml and values classes and parameters are missing in deserialized hash" do
    it "a node can roundtrip" do
      @node = Puppet::Node.from_data_hash({'name' => "mynode"})
      expect(YAML.load(@node.to_yaml).name).to eql("mynode")
    end

    it "errors if name is nil" do
      expect { Puppet::Node.from_data_hash({ })}.to raise_error(ArgumentError, /No name provided in serialized data/)
    end

  end

  describe "when converting to json" do
    before do
      @node = Puppet::Node.new("mynode")
    end

    it "provide its name" do
      expect(@node).to set_json_attribute('name').to("mynode")
    end

    it "includes the classes if set" do
      @node.classes = %w{a b c}
      expect(@node).to set_json_attribute("classes").to(%w{a b c})
    end

    it "does not include the classes if there are none" do
      expect(@node).to_not set_json_attribute('classes')
    end

    it "includes parameters if set" do
      @node.parameters = {"a" => "b", "c" => "d"}
      expect(@node).to set_json_attribute('parameters').to({"a" => "b", "c" => "d"})
    end

    it "does not include the parameters if there are none" do
      expect(@node).to_not set_json_attribute('parameters')
    end

    it "includes the environment" do
      @node.environment = "production"
      expect(@node).to set_json_attribute('environment').to('production')
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

    it "sets its name" do
      expect(Puppet::Node).to read_json_attribute('name').from(@node.to_pson).as("mynode")
    end

    it "includes the classes if set" do
      @node.classes = %w{a b c}
      expect(Puppet::Node).to read_json_attribute('classes').from(@node.to_pson).as(%w{a b c})
    end

    it "includes parameters if set" do
      @node.parameters = {"a" => "b", "c" => "d"}
      expect(Puppet::Node).to read_json_attribute('parameters').from(@node.to_pson).as({"a" => "b", "c" => "d"})
    end

    it "deserializes environment to environment_name as a string" do
      @node.environment = environment
      expect(Puppet::Node).to read_json_attribute('environment_name').from(@node.to_pson).as('bar')
    end
  end
end

describe Puppet::Node, "when initializing" do
  before do
    @node = Puppet::Node.new("testnode")
  end

  it "sets the node name" do
    expect(@node.name).to eq("testnode")
  end

  it "does not allow nil node names" do
    expect { Puppet::Node.new(nil) }.to raise_error(ArgumentError)
  end

  it "defaults to an empty parameter hash" do
    expect(@node.parameters).to eq({})
  end

  it "defaults to an empty class array" do
    expect(@node.classes).to eq([])
  end

  it "notes its creation time" do
    expect(@node.time).to be_instance_of(Time)
  end

  it "accepts parameters passed in during initialization" do
    params = {"a" => "b"}
    @node = Puppet::Node.new("testing", :parameters => params)
    expect(@node.parameters).to eq(params)
  end

  it "accepts classes passed in during initialization" do
    classes = %w{one two}
    @node = Puppet::Node.new("testing", :classes => classes)
    expect(@node.classes).to eq(classes)
  end

  it "always returns classes as an array" do
    @node = Puppet::Node.new("testing", :classes => "myclass")
    expect(@node.classes).to eq(["myclass"])
  end
end

describe Puppet::Node, "when merging facts" do
  before do
    @node = Puppet::Node.new("testnode")
    Puppet[:facts_terminus] = :memory
    Puppet::Node::Facts.indirection.save(Puppet::Node::Facts.new(@node.name, "one" => "c", "two" => "b"))
  end

  it "recovers with a Puppet::Error if something is thrown from the facts indirection" do
    Puppet::Node::Facts.indirection.expects(:find).raises "something bad happened in the indirector"
    expect { @node.fact_merge }.to raise_error(Puppet::Error, /Could not retrieve facts for testnode: something bad happened in the indirector/)
  end

  it "prefers parameters already set on the node over facts from the node" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    expect(@node.parameters["one"]).to eq("a")
  end

  it "adds passed parameters to the parameter list" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    expect(@node.parameters["two"]).to eq("b")
  end

  it "warns when a parameter value is not updated" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    Puppet.expects(:warning).with('The node parameter \'one\' for node \'testnode\' was already set to \'a\'. It could not be set to \'b\'')
    @node.merge "one" => "b"
  end

  it "accepts arbitrary parameters to merge into its parameters" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.merge "two" => "three"
    expect(@node.parameters["two"]).to eq("three")
  end

  context "with an env loader" do
    let(:environment) { Puppet::Node::Environment.create(:one, []) }
    let(:env_loader) { Puppet::Environments::Static.new(environment) }

    around do |example|
      Puppet.override(:environments => env_loader) do
        example.run
      end
    end

    it "adds the environment to the list of parameters" do
      Puppet[:environment] = "one"
      @node = Puppet::Node.new("testnode", :environment => "one")
      @node.merge "two" => "three"
      expect(@node.parameters["environment"]).to eq("one")
    end

    it "nots set the environment if it is already set in the parameters" do
      Puppet[:environment] = "one"
      @node = Puppet::Node.new("testnode", :environment => "one")
      @node.merge "environment" => "two"
      expect(@node.parameters["environment"]).to eq("two")
    end
  end
end

describe Puppet::Node, "when indirecting" do
  it "defaults to the 'plain' node terminus" do
    Puppet::Node.indirection.reset_terminus_class

    expect(Puppet::Node.indirection.terminus_class).to eq(:plain)
  end
end

describe Puppet::Node, "when generating the list of names to search through" do
  before do
    @node = Puppet::Node.new("foo.domain.com", :parameters => {"hostname" => "yay", "domain" => "domain.com"})
  end

  it "returns an array of names" do
    expect(@node.names).to be_instance_of(Array)
  end

  describe "and the node name is fully qualified" do
    it "contains an entry for each part of the node name" do
      expect(@node.names).to include("foo.domain.com")
      expect(@node.names).to include("foo.domain")
      expect(@node.names).to include("foo")
    end
  end

  it "includes the node's fqdn" do
    expect(@node.names).to include("yay.domain.com")
  end

  it "combines and include the node's hostname and domain if no fqdn is available" do
    expect(@node.names).to include("yay.domain.com")
  end

  it "contains an entry for each name available by stripping a segment of the fqdn" do
    @node.parameters["fqdn"] = "foo.deep.sub.domain.com"
    expect(@node.names).to include("foo.deep.sub.domain")
    expect(@node.names).to include("foo.deep.sub")
  end

  describe "and :node_name is set to 'cert'" do
    before do
      Puppet[:strict_hostname_checking] = false
      Puppet[:node_name] = "cert"
    end

    it "uses the passed-in key as the first value" do
      expect(@node.names[0]).to eq("foo.domain.com")
    end

    describe "and strict hostname checking is enabled" do
      it "only uses the passed-in key" do
        Puppet[:strict_hostname_checking] = true
        expect(@node.names).to eq(["foo.domain.com"])
      end
    end
  end

  describe "and :node_name is set to 'facter'" do
    before do
      Puppet[:strict_hostname_checking] = false
      Puppet[:node_name] = "facter"
    end

    it "uses the node's 'hostname' fact as the first value" do
      expect(@node.names[0]).to eq("yay")
    end
  end
end
