#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-02-20.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

class TestASTDefinition < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
	AST = Puppet::Parser::AST

    def test_initialize
        parser = mkparser

        # Create a new definition
        klass = parser.newdefine "yayness",
            :arguments => [["owner", stringobj("nobody")], %w{mode}],
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/$name",
                        "owner" => varref("owner"), "mode" => varref("mode"))]
            )

        # Test validattr? a couple different ways
        [:owner, "owner", :schedule, "schedule"].each do |var|
            assert(klass.validattr?(var), "%s was not considered valid" % var.inspect)
        end

        [:random, "random"].each do |var|
            assert(! klass.validattr?(var), "%s was considered valid" % var.inspect)
        end

    end

    def test_evaluate
        parser = mkparser
        config = mkconfig
        scope = config.topscope
        klass = parser.newdefine "yayness",
            :arguments => [["owner", stringobj("nobody")], %w{mode}],
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/$name",
                        "owner" => varref("owner"), "mode" => varref("mode"))]
            )

        resource = stub 'resource',
            :title => "first",
            :name => "first",
            :type => "yayness",
            :to_hash => {"mode" => "755"},
            :exported => false,
            :virtual => false 

        resource.stubs(:title)
        assert_nothing_raised do
            klass.evaluate(:scope => scope, :resource => resource)
        end

        firstobj = config.findresource("File[/tmp/first]")
        assert(firstobj, "Did not create /tmp/first obj")

        assert_equal("file", firstobj.type)
        assert_equal("/tmp/first", firstobj.title)
        assert_equal("nobody", firstobj[:owner])
        assert_equal("755", firstobj[:mode])

        # Make sure we can't evaluate it with the same args
        assert_raise(Puppet::ParseError) do
            klass.evaluate(:scope => scope, :resource => resource)
        end

        # Now create another with different args
        resource2 = stub 'resource',
            :title => "second",
            :name => "second",
            :type => "yayness",
            :to_hash => {"mode" => "755", "owner" => "daemon"},
            :exported => false,
            :virtual => false 

        assert_nothing_raised do
            klass.evaluate(:scope => scope, :resource => resource2)
        end

        secondobj = config.findresource("File[/tmp/second]")
        assert(secondobj, "Did not create /tmp/second obj")

        assert_equal("file", secondobj.type)
        assert_equal("/tmp/second", secondobj.title)
        assert_equal("daemon", secondobj[:owner])
        assert_equal("755", secondobj[:mode])
    end

    # #539 - definitions should support both names and titles
    def test_names_and_titles
        parser = mkparser
        scope = mkscope :parser => parser

        [
            {:name => "one", :title => "two"},
            {:title => "mytitle"}
        ].each_with_index do |hash, i|
            # Create a definition that uses both name and title.  Put this
            # inside the loop so the subscope expectations work.
            klass = parser.newdefine "yayness%s" % i

            resource = stub 'resource',
                :title => hash[:title],
                :name => hash[:name] || hash[:title],
                :type => "yayness%s" % i,
                :to_hash => {},
                :exported => false,
                :virtual => false 

            subscope = klass.subscope(scope, resource)

            klass.expects(:subscope).returns(subscope)

            if hash[:name]
                resource.stubs(:to_hash).returns({:name => hash[:name]})
            end

            assert_nothing_raised("Could not evaluate definition with %s" % hash.inspect) do
                klass.evaluate(:scope => scope, :resource => resource)
            end

            name = hash[:name] || hash[:title]
            title = hash[:title]

            assert_equal(name, subscope.lookupvar("name"),
                "Name did not get set correctly")
            assert_equal(title, subscope.lookupvar("title"),
                "title did not get set correctly")

            [:name, :title].each do |param|
                val = resource.send(param)
                assert(subscope.tags.include?(val),
                    "Scope was not tagged with %s '%s'" % [param, val])
            end
        end
    end

    # Testing the root cause of #615.  We should be using the fqname for the type, instead
    # of just the short name.
    def test_fully_qualified_types
        parser = mkparser
        klass = parser.newclass("one::two")

        assert_equal("one::two", klass.classname, "Class did not get fully qualified class name")
    end
end
