#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-02-20.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'
require 'mocha'

class TestASTHostClass < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
	AST = Puppet::Parser::AST

    def test_hostclass
        scope = mkscope
        parser = scope.compile.parser

        # Create the class we're testing, first with no parent
        klass = parser.newclass "first",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp",
                        "owner" => "nobody", "mode" => "755")]
            )

        resource = Puppet::Parser::Resource.new(:type => "class", :title => "first", :scope => scope)
        assert_nothing_raised do
            klass.evaluate(:scope => scope, :resource => resource)
        end

        # Then try it again
        assert_nothing_raised do
            klass.evaluate(:scope => scope, :resource => resource)
        end

        assert(scope.compile.class_scope(klass), "Class was not considered evaluated")

        tmp = scope.findresource("File[/tmp]")
        assert(tmp, "Could not find file /tmp")
        assert_equal("nobody", tmp[:owner])
        assert_equal("755", tmp[:mode])

        # Now create a couple more classes.
        newbase = parser.newclass "newbase",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/other",
                        "owner" => "nobody", "mode" => "644")]
            )

        newsub = parser.newclass "newsub",
            :parent => "newbase",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/yay",
                        "owner" => "nobody", "mode" => "755"),
                    resourceoverride("file", "/tmp/other",
                            "owner" => "daemon")
                ]
            )

        # Override a different variable in the top scope.
        moresub = parser.newclass "moresub",
            :parent => "newbase",
            :code => AST::ASTArray.new(
                :children => [resourceoverride("file", "/tmp/other",
                            "mode" => "755")]
            )

        assert_nothing_raised do
            newsub.evaluate(:scope => scope, :resource => resource)
        end

        assert_nothing_raised do
            moresub.evaluate(:scope => scope, :resource => resource)
        end

        assert(scope.compile.class_scope(newbase), "Did not eval newbase")
        assert(scope.compile.class_scope(newsub), "Did not eval newsub")

        yay = scope.findresource("File[/tmp/yay]")
        assert(yay, "Did not find file /tmp/yay")
        assert_equal("nobody", yay[:owner])
        assert_equal("755", yay[:mode])

        other = scope.findresource("File[/tmp/other]")
        assert(other, "Did not find file /tmp/other")
        assert_equal("daemon", other[:owner])
        assert_equal("755", other[:mode])
    end

    # Make sure that classes set their namespaces to themselves.  This
    # way they start looking for definitions in their own namespace.
    def test_hostclass_namespace
        scope = mkscope
        parser = scope.compile.parser

        # Create a new class
        klass = nil
        assert_nothing_raised do
            klass = parser.newclass "funtest"
        end

        # Now define a definition in that namespace

        define = nil
        assert_nothing_raised do
            define = parser.newdefine "funtest::mydefine"
        end

        assert_equal("funtest", klass.namespace,
            "component namespace was not set in the class")

        assert_equal("funtest", define.namespace,
            "component namespace was not set in the definition")

        newscope = klass.subscope(scope, mock("resource"))

        assert_equal(["funtest"], newscope.namespaces,
            "Scope did not inherit namespace")

        # Now make sure we can find the define
        assert(newscope.finddefine("mydefine"),
            "Could not find definition in my enclosing class")
    end

    # Make sure that our scope is a subscope of the parentclass's scope.
    # At the same time, make sure definitions in the parent class can be
    # found within the subclass (#517).
    def test_parent_scope_from_parentclass
        scope = mkscope
        parser = scope.compile.parser

        source = parser.newclass ""
        parser.newclass("base")
        fun = parser.newdefine("base::fun")
        parser.newclass("middle", :parent => "base")
        parser.newclass("sub", :parent => "middle")
        scope = mkscope :parser => parser

        ret = nil
        assert_nothing_raised do
            ret = scope.compile.evaluate_classes(["sub"], scope)
        end
        scope.compile.send(:evaluate_generators)

        subscope = scope.compile.class_scope(scope.findclass("sub"))
        assert(subscope, "could not find sub scope")
        mscope = scope.compile.class_scope(scope.findclass("middle"))
        assert(mscope, "could not find middle scope")
        pscope = scope.compile.class_scope(scope.findclass("base"))
        assert(pscope, "could not find parent scope")

        assert(pscope == mscope.parent, "parent scope of middle was not set correctly")
        assert(mscope == subscope.parent, "parent scope of sub was not set correctly")

        result = mscope.finddefine("fun")
        assert(result, "could not find parent-defined definition from middle")
        assert(fun == result, "found incorrect parent-defined definition from middle")

        result = subscope.finddefine("fun")
        assert(result, "could not find parent-defined definition from sub")
        assert(fun == result, "found incorrect parent-defined definition from sub")
    end
end
