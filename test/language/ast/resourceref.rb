#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-07-8.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'

class TestASTResourceRef < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
	AST = Puppet::Parser::AST
    
    def newref(type, title)
        AST::ResourceRef.new(:type => type, :title => AST::String.new(:value => title))
    end

    def setup
        super
        @interp = mkinterp
        @scope = mkscope :interp => @interp
    end

    def test_evaluate
        @interp.newdefine "one::two"
        @interp.newdefine "one-two"
        [%w{file /tmp/yay}, %w{one::two three}, %w{one-two three}].each do |type, title|
            ref = newref(type, title)

            evaled = nil
            assert_nothing_raised("Could not evaluate resource ref") do
                evaled = ref.evaluate(:scope => @scope)
            end

            assert_equal(type, evaled.type, "Type did not translate correctly")
            assert_equal(title, evaled.title, "Title did not translate correctly")
        end
    end

    # Related to #706, make sure resource references correctly translate to qualified types.
    def test_scoped_references
        @interp.newdefine "one"
        @interp.newdefine "one::two"
        @interp.newdefine "three"
        twoscope = @scope.newscope(:type => "one", :namespace => "one")
        assert(twoscope.finddefine("two"), "Could not find 'two' definition")
        title = "title"

        # First try an unqualified type
        assert_equal("one::two", newref("two", title).evaluate(:scope => twoscope).type,
            "Defined type was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("one", newref("one", title).evaluate(:scope => twoscope).type,
            "Unqualified defined type was not handled correctly")

        # Then a builtin type
        assert_equal("file", newref("file", title).evaluate(:scope => twoscope).type,
            "Builtin type was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newref("nosuchtype", title).evaluate(:scope => twoscope)
        end
    end
end

# $Id$
