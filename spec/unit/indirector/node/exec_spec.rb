#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/node/exec'
require 'puppet/indirector/request'

describe Puppet::Node::Exec do
  before do
    @indirection = mock 'indirection'
    Puppet.settings[:external_nodes] = File.expand_path("/echo")
    @searcher = Puppet::Node::Exec.new
  end

  describe "when constructing the command to run" do
    it "should use the external_node script as the command" do
      Puppet[:external_nodes] = "/bin/echo"
      expect(@searcher.command).to eq(%w{/bin/echo})
    end

    it "should throw an exception if no external node command is set" do
      Puppet[:external_nodes] = "none"
      expect { @searcher.find(stub('request', :key => "foo")) }.to raise_error(ArgumentError)
    end
  end

  describe "when handling the results of the command" do
    let(:testing_env) { Puppet::Node::Environment.create(:testing, []) }
    let(:other_env) { Puppet::Node::Environment.create(:other, []) }
    let(:request) { Puppet::Indirector::Request.new(:node, :find, @name, nil) }
    before do
      @name = "yay"
      @node = Puppet::Node.new(@name)
      @node.stubs(:fact_merge)
      Puppet::Node.expects(:new).with(@name).returns(@node)
      @result = {}
      # Use a local variable so the reference is usable in the execute definition.
      result = @result
      @searcher.meta_def(:execute) do |command, arguments|
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
      # Use an empty hash
      expect(@searcher.find(request)).to equal(@node)
    end

    it "should set the resulting parameters as the node parameters" do
      @result[:parameters] = {"a" => "b", "c" => "d"}
      @searcher.find(request)
      expect(@node.parameters).to eq({"a" => "b", "c" => "d", "environment" => "*root*"})
    end

    it "should set the resulting classes as the node classes" do
      @result[:classes] = %w{one two}
      @searcher.find(request)
      expect(@node.classes).to eq([ 'one', 'two' ])
    end

    it "should merge facts from the request if supplied" do
      facts = Puppet::Node::Facts.new('test', 'foo' => 'bar')
      request.options[:facts] = facts
      @node.expects(:fact_merge).with(facts)
      @searcher.find(request)
    end

    it "should set the node's environment if one is provided" do
      @result[:environment] = "testing"
      @searcher.find(request)
      expect(@node.environment.name).to eq(:testing)
    end

    it "should set the node's environment based on the request if not otherwise provided" do
      request.environment = "other"
      @searcher.find(request)
      expect(@node.environment.name).to eq(:other)
    end
  end
end
