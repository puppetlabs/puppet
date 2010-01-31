#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-07-8.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/parsertesting'

class TestASTResourceReference < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::ParserTesting
    AST = Puppet::Parser::AST

    def newref(type, title)
        AST::ResourceReference.new(:type => type, :title => AST::String.new(:value => title))
    end

    def setup
        super
        @scope = mkscope
        @parser = Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
    end

    # Related to #706, make sure resource references correctly translate to qualified types.
    def test_scoped_references
        @parser.newdefine "one"
        @parser.newdefine "one::two"
        @parser.newdefine "three"
        twoscope = @scope.newscope(:namespace => "one")
        assert(twoscope.find_definition("two"), "Could not find 'two' definition")
        title = "title"

        # First try a qualified type
        assert_equal("One::Two", newref("two", title).evaluate(twoscope).type,
            "Defined type was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("One", newref("one", title).evaluate(twoscope).type,
            "Unqualified defined type was not handled correctly")

        # Then an unqualified type from within the one namespace
        assert_equal("Three", newref("three", title).evaluate(twoscope).type,
            "Defined type was not made fully qualified")

        # Then a builtin type
        assert_equal("File", newref("file", title).evaluate(twoscope).type,
            "Builtin type was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newref("nosuchtype", title).evaluate(twoscope)
        end

        # Now run the same tests, but with the classes
        @parser.newclass "four"
        @parser.newclass "one::five"

        # First try an unqualified type
        assert_equal("four", newref("class", "four").evaluate(twoscope).title,
            "Unqualified class was not found")

        # Then a qualified class
        assert_equal("one::five", newref("class", "five").evaluate(twoscope).title,
            "Class was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("four", newref("class", "four").evaluate(twoscope).title,
            "Unqualified class was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newref("class", "nosuchclass").evaluate(twoscope)
        end
    end
end
