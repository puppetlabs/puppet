#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-0419.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'

class TestVariable < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
	AST = Puppet::Parser::AST
    
    def setup
        super
        @interp = mkinterp
        @scope = mkscope :interp => @interp
        @name = "myvar"
        @var = AST::Variable.new(:value => @name)
    end

    def test_evaluate
        assert_equal("", @var.evaluate(:scope => @scope), "did not return empty string on unset var")
        @scope.setvar(@name, "something")
        assert_equal("something", @var.evaluate(:scope => @scope), "incorrect variable value")
    end
end

# $Id$
