#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-07-8.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/parsertesting'

class TestASTResource< Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::ParserTesting
    AST = Puppet::Parser::AST

    def setup
        super
        @scope = mkscope
        @parser = @scope.compiler.parser
    end

    def newdef(type, title, params = nil)
        params ||= AST::ASTArray.new(:children => [])
        AST::Resource.new(:type => type, :title => AST::String.new(:value => title), :params => params)
    end

    # Related to #806, make sure resources always look up the full path to the resource.
    def test_scoped_types
        @parser.newdefine "one"
        @parser.newdefine "one::two"
        @parser.newdefine "three"
        twoscope = @scope.newscope(:namespace => "one")
        twoscope.resource = @scope.resource
        assert(twoscope.find_definition("two"), "Could not find 'two' definition")
        title = "title"

        # First try a qualified type
        assert_equal("One::Two", newdef("two", title).evaluate(twoscope)[0].type,
            "Defined type was not made fully qualified")

        # Then try a type that does not need to be qualified
        assert_equal("One", newdef("one", title).evaluate(twoscope)[0].type,
            "Unqualified defined type was not handled correctly")

        # Then an unqualified type from within the one namespace
        assert_equal("Three", newdef("three", title).evaluate(twoscope)[0].type,
            "Defined type was not made fully qualified")

        # Then a builtin type
        assert_equal("File", newdef("file", title).evaluate(twoscope)[0].type,
            "Builtin type was not handled correctly")

        # Now try a type that does not exist, which should throw an error.
        assert_raise(Puppet::ParseError, "Did not fail on a missing type in a resource reference") do
            newdef("nosuchtype", title).evaluate(twoscope)
        end
    end
end
