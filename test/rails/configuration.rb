#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppet/rails'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'puppettest/railstesting'


class ConfigurationRailsTests < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting
    AST = Puppet::Parser::AST
    confine "No rails support" => Puppet.features.rails?

    # We need to make sure finished objects are stored in the db.
    def test_finish_before_store
        railsinit
        config = mkconfig
        config.ast_nodes = true
        parser = config.parser

        node = parser.newnode [config.node.name], :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/yay", :group => "root"),
            defaultobj("file", :owner => "root")
        ])

        # Now do the rails crap
        Puppet[:storeconfigs] = true

        Puppet::Rails::Host.expects(:store).with do |node, resources|
            if res = resources.find { |r| r.type == "file" and r.title == "/tmp/yay" }
                assert_equal("root", res["owner"], "Did not set default on resource")
                true
            else
                raise "Resource was not passed to store()"
            end
        end
        config.compile
    end

    def test_hoststorage
        assert_nothing_raised {
            Puppet[:storeconfigs] = true
        }

        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => file,
                :UseNodes => false,
                :ForkSave => false
            )
        }

        facts = {}
        Facter.each { |fact, val| facts[fact] = val }
        node = mknode(facts["hostname"])
        node.parameters = facts

        objects = nil
        assert_nothing_raised {
            objects = interp.compile(node)
        }

        obj = Puppet::Rails::Host.find_by_name(node.name)
        assert(obj, "Could not find host object")
    end
end
