#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'mocha'
require 'puppettest'
require 'puppet/node'

class TestNode < Test::Unit::TestCase
    include PuppetTest
    Node = Puppet::Node

    # Make sure we get all the defaults correctly.
    def test_initialize
        node = nil
        assert_nothing_raised("could not create a node without classes or parameters") do
            node = Node.new("testing")
        end
        assert_equal("testing", node.name, "Did not set name correctly")
        assert_equal({}, node.parameters, "Node parameters did not default correctly")
        assert_equal([], node.classes, "Node classes did not default correctly")
        assert_instance_of(Time, node.time, "Did not set the creation time")

        # Now test it with values for both
        params = {"a" => "b"}
        classes = %w{one two}
        assert_nothing_raised("could not create a node with classes and parameters") do
            node = Node.new("testing", :parameters => params, :classes => classes)
        end
        assert_equal("testing", node.name, "Did not set name correctly")
        assert_equal(params, node.parameters, "Node parameters did not get set correctly")
        assert_equal(classes, node.classes, "Node classes did not get set correctly")

        # And make sure a single class gets turned into an array
        assert_nothing_raised("could not create a node with a class as a string") do
            node = Node.new("testing", :classes => "test")
        end
        assert_equal(%w{test}, node.classes, "A node class string was not converted to an array")

        # Make sure we get environments
        assert_nothing_raised("could not create a node with an environment") do
            node = Node.new("testing", :environment => "test")
        end
        assert_equal("test", node.environment, "Environment was not set")

        # Now make sure we get the default env
        Puppet[:environment] = "prod"
        assert_nothing_raised("could not create a node with no environment") do
            node = Node.new("testing")
        end
        assert_equal("prod", node.environment, "Did not get default environment")

        # But that it stays nil if there's no default env set
        Puppet[:environment] = ""
        assert_nothing_raised("could not create a node with no environment and no default env") do
            node = Node.new("testing")
        end
        assert_nil(node.environment, "Got a default env when none was set")

    end

    # Verify that the node source wins over facter.
    def test_fact_merge
        node = Node.new("yay", :parameters => {"a" => "one", "b" => "two"})

        assert_nothing_raised("Could not merge parameters") do
            node.fact_merge("b" => "three", "c" => "yay")
        end
        params = node.parameters
        assert_equal("one", params["a"], "Lost nodesource parameters in parameter merge")
        assert_equal("two", params["b"], "Overrode nodesource parameters in parameter merge")
        assert_equal("yay", params["c"], "Did not get facts in parameter merge")
    end
end

