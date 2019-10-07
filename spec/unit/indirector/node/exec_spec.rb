require 'spec_helper'

require 'puppet/indirector/node/exec'
require 'puppet/indirector/request'

describe Puppet::Node::Exec do
  let(:indirection) { mock 'indirection' }
  let(:searcher) { Puppet::Node::Exec.new }

  before do
    Puppet.settings[:external_nodes] = File.expand_path("/echo")
  end

  describe "when constructing the command to run" do
    it "should use the external_node script as the command" do
      Puppet[:external_nodes] = "/bin/echo"
      expect(searcher.command).to eq(%w{/bin/echo})
    end

    it "should throw an exception if no external node command is set" do
      Puppet[:external_nodes] = "none"
      expect { searcher.find(double('request', :key => "foo")) }.to raise_error(ArgumentError)
    end
  end

  describe "when handling the results of the command" do
    let(:testing_env) { Puppet::Node::Environment.create(:testing, []) }
    let(:other_env) { Puppet::Node::Environment.create(:other, []) }
    let(:request) { Puppet::Indirector::Request.new(:node, :find, name, environment: testing_env) }
    let(:name) { 'yay' }
    let(:facts) { Puppet::Node::Facts.new(name, {}) }

    before do
      allow(Puppet::Node::Facts.indirection).to receive(:find).and_return(facts)

      @result = {}
      # Use a local variable so the reference is usable in the execute definition.
      result = @result
      searcher.meta_def(:execute) do |command, arguments|
        return YAML.dump(result)
      end
    end

    around do |example|
      envs = Puppet::Environments::Static.new(testing_env, other_env)

      Puppet.override(:environments => envs) do
        example.run
      end
    end

    it "should translate the YAML into a Node instance" do
      @result = {}
      node = searcher.find(request)
      expect(node.name).to eq(name)
      expect(node.parameters).to include('environment')
      expect(node.facts).to eq(facts)
      expect(node.environment.name).to eq(:'*root*') # request env is ignored
    end

    it "should set the resulting parameters as the node parameters" do
      @result[:parameters] = {"a" => "b", "c" => "d"}
      node = searcher.find(request)
      expect(node.parameters).to eq({"a" => "b", "c" => "d", "environment" => "*root*"})
    end

    it "accepts symbolic parameter names" do
      @result[:parameters] = {:name => "value"}
      node = searcher.find(request)
      expect(node.parameters).to include({:name => "value"})
    end

    it "raises when deserializing unacceptable objects" do
      @result[:parameters] = {'name' => Object.new }

      expect {
        searcher.find(request)
      }.to raise_error(Puppet::Error,
                       /Could not load external node results for yay: \(<unknown>\): Tried to load unspecified class: Object/)
    end

    it "should set the resulting classes as the node classes" do
      @result[:classes] = %w{one two}
      node = searcher.find(request)
      expect(node.classes).to eq([ 'one', 'two' ])
    end

    it "should merge facts from the request if supplied" do
      facts = Puppet::Node::Facts.new('test', 'foo' => 'bar')
      request.options[:facts] = facts
      node = searcher.find(request)
      expect(node.facts).to eq(facts)
    end

    it "should set the node's environment if one is provided" do
      @result[:environment] = "testing"
      node = searcher.find(request)
      expect(node.environment.name).to eq(:testing)
    end

    it "should set the node's environment based on the request if not otherwise provided" do
      request.environment = "other"
      node = searcher.find(request)
      expect(node.environment.name).to eq(:other)
    end
  end
end
