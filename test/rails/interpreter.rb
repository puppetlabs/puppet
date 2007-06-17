#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppet/rails'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'puppettest/railstesting'


class InterpreterRailsTests < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting
    AST = Puppet::Parser::AST
    NodeDef = Puppet::Parser::Interpreter::NodeDef
    confine "No rails support" => Puppet.features.rails?

    # We need to make sure finished objects are stored in the db.
    def test_finish_before_store
        railsinit
        interp = mkinterp

        node = interp.newnode ["myhost"], :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/yay", :group => "root"),
            defaultobj("file", :owner => "root")
        ])

        interp.newclass "myclass", :code => AST::ASTArray.new(:children => [
        ])

        interp.newclass "sub", :parent => "myclass",
            :code => AST::ASTArray.new(:children => [
                resourceoverride("file", "/tmp/yay", :owner => "root")
            ]
        )

        # Now do the rails crap
        Puppet[:storeconfigs] = true

        interp.evaluate("myhost", {})

        # And then retrieve the object from rails
        #res = Puppet::Rails::Resource.find_by_restype_and_title("file", "/tmp/yay", :include => {:param_values => :param_names})
        res = Puppet::Rails::Resource.find_by_restype_and_title("file", "/tmp/yay")

        assert(res, "Did not get resource from rails")

        params = res.parameters

        assert_equal(["root"], params["owner"], "Did not get correct value for owner param")
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

        objects = nil
        assert_nothing_raised {
            objects = interp.run(facts["hostname"], facts)
        }

        obj = Puppet::Rails::Host.find_by_name(facts["hostname"])
        assert(obj, "Could not find host object")
    end
end
