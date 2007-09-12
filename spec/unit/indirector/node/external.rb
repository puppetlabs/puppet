#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'yaml'
require 'puppet/indirector'

describe Puppet::Indirector.terminus(:node, :external), " when searching for nodes" do
    require 'puppet/node'

    before do
        Puppet.config[:external_nodes] = "/yay/ness"
        @searcher = Puppet::Indirector.terminus(:node, :external).new

        # Set the searcher up so that we do not need to actually call the
        # external script.
        @searcher.meta_def(:execute) do |command|
            name = command.last.chomp
            result = {}

            if name =~ /a/
                result[:parameters] = {'one' => command.last + '1', 'two' => command.last + '2'}
            end

            if name =~ /p/
                result['classes'] = [1,2,3].collect { |n| command.last + n.to_s }
            end

            return YAML.dump(result)
        end
    end

    it "should throw an exception if the node_source is external but no external node command is set" do
        Puppet[:external_nodes] = "none"
        proc { @searcher.get("foo") }.should raise_error(ArgumentError)
    end

    it "should throw an exception if the external node source is not fully qualified" do
        Puppet[:external_nodes] = "mycommand"
        proc { @searcher.get("foo") }.should raise_error(ArgumentError)
    end

    it "should execute the command with the node name as the only argument" do
        command = [Puppet[:external_nodes], "yay"]
        @searcher.expects(:execute).with(command).returns("")
        @searcher.get("yay")
    end

    it "should return a node object" do
        @searcher.get("apple").should be_instance_of(Puppet::Node)
    end

    it "should set the node's name" do
        @searcher.get("apple").name.should == "apple"
    end
    
    # If we use a name that has a 'p' but no 'a', then our test generator
    # will return classes but no parameters.
    it "should be able to configure a node's classes" do
        node = @searcher.get("plum")
        node.classes.should == %w{plum1 plum2 plum3}
        node.parameters.should == {}
    end
    
    # If we use a name that has an 'a' but no 'p', then our test generator
    # will return parameters but no classes.
    it "should be able to configure a node's parameters" do
        node = @searcher.get("guava")
        node.classes.should == []
        node.parameters.should == {"one" => "guava1", "two" => "guava2"}
    end
    
    it "should be able to configure a node's classes and parameters" do
        node = @searcher.get("apple")
        node.classes.should == %w{apple1 apple2 apple3}
        node.parameters.should == {"one" => "apple1", "two" => "apple2"}
    end

    it "should merge node facts with returned parameters" do
        facts = Puppet::Node::Facts.new("apple", "three" => "four")
        Puppet::Node::Facts.expects(:get).with("apple").returns(facts)
        node = @searcher.get("apple")
        node.parameters["three"].should == "four"
    end

    it "should return nil when it cannot find the node" do
        @searcher.get("honeydew").should be_nil
    end
    
    # Make sure a nodesearch with arguments works
    def test_nodesearch_external_arguments
        mapper = mk_node_mapper
        Puppet[:external_nodes] = "#{mapper} -s something -p somethingelse"
        searcher = mk_searcher(:external)
        node = nil
        assert_nothing_raised do
            node = searcher.nodesearch("apple")
        end
        assert_instance_of(SimpleNode, node, "did not create node")
    end
    
    # A wrapper test, to make sure we're correctly calling the external search method.
    def test_nodesearch_external_functional
        mapper = mk_node_mapper
        searcher = mk_searcher(:external)
        
        Puppet[:external_nodes] = mapper
        
        node = nil
        assert_nothing_raised do
            node = searcher.nodesearch("apple")
        end
        assert_instance_of(SimpleNode, node, "did not create node")
    end

    after do
        Puppet.config.clear
    end
end
