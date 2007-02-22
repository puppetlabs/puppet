#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-02-20.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

class TestASTComponent < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
	AST = Puppet::Parser::AST

    def test_component
        interp, scope, source = mkclassframing

        # Create a new definition
        klass = interp.newdefine "yayness",
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
        # Now call it a couple of times
        # First try it without a required param
        assert_raise(Puppet::ParseError) do
            klass.evaluate(:scope => scope,
                :name => "bad",
                :arguments => {"owner" => "nobody"}
            )
        end

        # And make sure it didn't create the file
        assert_nil(scope.findresource("File[/tmp/bad]"),
            "Made file with invalid params")

        assert_nothing_raised do
            klass.evaluate(:scope => scope,
                :name => "first",
                :arguments => {"mode" => "755"}
            )
        end

        firstobj = scope.findresource("File[/tmp/first]")
        assert(firstobj, "Did not create /tmp/first obj")

        assert_equal("file", firstobj.type)
        assert_equal("/tmp/first", firstobj.title)
        assert_equal("nobody", firstobj[:owner])
        assert_equal("755", firstobj[:mode])

        # Make sure we can't evaluate it with the same args
        assert_raise(Puppet::ParseError) do
            klass.evaluate(:scope => scope,
                :name => "first",
                :arguments => {"mode" => "755"}
            )
        end

        # Now create another with different args
        assert_nothing_raised do
            klass.evaluate(:scope => scope,
                :name => "second",
                :arguments => {"mode" => "755", "owner" => "daemon"}
            )
        end

        secondobj = scope.findresource("File[/tmp/second]")
        assert(secondobj, "Did not create /tmp/second obj")

        assert_equal("file", secondobj.type)
        assert_equal("/tmp/second", secondobj.title)
        assert_equal("daemon", secondobj[:owner])
        assert_equal("755", secondobj[:mode])
    end
end
# $Id$
