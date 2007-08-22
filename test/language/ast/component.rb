#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-02-20.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

class TestASTComponent < Test::Unit::TestCase
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

        # Now call it a couple of times
        # First try it without a required param
        assert_raise(Puppet::ParseError, "Did not fail when a required parameter was not provided") do
            klass.evaluate_resource(:scope => scope,
                :name => "bad",
                :arguments => {"owner" => "nobody"}
            )
        end

        # And make sure it didn't create the file
        assert_nil(config.findresource("File[/tmp/bad]"),
            "Made file with invalid params")

        assert_nothing_raised do
            klass.evaluate_resource(:scope => scope,
                :title => "first",
                :arguments => {"mode" => "755"}
            )
        end

        firstobj = config.findresource("File[/tmp/first]")
        assert(firstobj, "Did not create /tmp/first obj")

        assert_equal("file", firstobj.type)
        assert_equal("/tmp/first", firstobj.title)
        assert_equal("nobody", firstobj[:owner])
        assert_equal("755", firstobj[:mode])

        # Make sure we can't evaluate it with the same args
        assert_raise(Puppet::ParseError) do
            klass.evaluate_resource(:scope => scope,
                :title => "first",
                :arguments => {"mode" => "755"}
            )
        end

        # Now create another with different args
        assert_nothing_raised do
            klass.evaluate_resource(:scope => scope,
                :title => "second",
                :arguments => {"mode" => "755", "owner" => "daemon"}
            )
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
        parser, scope, source = mkclassframing

        [
        {:name => "one", :title => "two"},
        {:title => "mytitle"},
        ].each_with_index do |hash, i|

            # Create a definition that uses both name and title
            klass = parser.newdefine "yayness%s" % i

            subscope = klass.subscope(scope, "yayness%s" % i)

            klass.expects(:subscope).returns(subscope)

            args = {:title => hash[:title]}
            if hash[:name]
                args[:arguments] = {:name => hash[:name]}
            end
            args[:scope] = scope
            assert_nothing_raised("Could not evaluate definition with %s" % hash.inspect) do
                klass.evaluate_resource(args)
            end

            name = hash[:name] || hash[:title]
            title = hash[:title]
            args[:name] ||= name

            assert_equal(name, subscope.lookupvar("name"),
                "Name did not get set correctly")
            assert_equal(title, subscope.lookupvar("title"),
                "title did not get set correctly")

            [:name, :title].each do |param|
                val = args[param]
                assert(subscope.tags.include?(val),
                    "Scope was not tagged with %s" % val)
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
# $Id$
