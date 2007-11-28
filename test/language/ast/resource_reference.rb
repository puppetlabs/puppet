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
        @parser = @scope.compile.parser
    end

    def test_evaluate
        @parser.newdefine "one::two"
        @parser.newdefine "one-two"
        [%w{File /tmp/yay}, %w{One::Two three}, %w{One-two three}].each do |type, title|
            ref = newref(type, title)

            evaled = nil
            assert_nothing_raised("Could not evaluate resource ref") do
                evaled = ref.evaluate(:scope => @scope)
            end

            assert_equal(type, evaled.type, "Type did not translate correctly")
            assert_equal(title, evaled.title, "Title did not translate correctly")
        end
    end

    def test_finding_classes_for_reference
        @parser.newclass "one"
        ref = newref("Class", "one")
        evaled = nil
        assert_nothing_raised("Could not evaluate resource ref") do
            evaled = ref.evaluate(:scope => @scope)
        end

        assert_equal("Class", evaled.type, "Did not set type to 'class'")
        assert_equal("one", evaled.title, "Did not look up class corectly")
    end

    # Related to #706, make sure resource references correctly translate to qualified types.
    def test_scoped_references
        @parser.newdefine "one"
        @parser.newdefine "one::two"
        @parser.newdefine "three"
        twoscope = @scope.newscope(:namespace => "one")
        assert(twoscope.finddefine("two"), "Could not find 'two' definition")
        title = "title"

        # First try a qualified type
        assert_equal("One::Two", newref("two", title).evaluate(:scope => twoscope).type,
            "Defined type was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("One", newref("one", title).evaluate(:scope => twoscope).type,
            "Unqualified defined type was not handled correctly")

        # Then an unqualified type from within the one namespace
        assert_equal("Three", newref("three", title).evaluate(:scope => twoscope).type,
            "Defined type was not made fully qualified")

        # Then a builtin type
        assert_equal("File", newref("file", title).evaluate(:scope => twoscope).type,
            "Builtin type was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newref("nosuchtype", title).evaluate(:scope => twoscope)
        end

        # Now run the same tests, but with the classes
        @parser.newclass "four"
        @parser.newclass "one::five"

        # First try an unqualified type
        assert_equal("four", newref("class", "four").evaluate(:scope => twoscope).title,
            "Unqualified class was not found")

        # Then a qualified class
        assert_equal("one::five", newref("class", "five").evaluate(:scope => twoscope).title,
            "Class was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("four", newref("class", "four").evaluate(:scope => twoscope).title,
            "Unqualified class was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newref("class", "nosuchclass").evaluate(:scope => twoscope)
        end
    end
end
