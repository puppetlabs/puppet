#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-12-22.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'

class TestCaseStatement < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
	AST = Puppet::Parser::AST
	
	class ActiveAST < FakeAST
	    def self.clear
	        $evaluated = []
        end
	    def evaluate
	        $evaluated ||= []
	        $evaluated << @evaluate
        end
    end
	
	def test_evaluate
        ast = nil
        scope = mkscope
        param = nameobj("MyParam")

        hash = {
            "myparam" => ActiveAST.new("lower"),
            "MyParam" => ActiveAST.new("upper"),
            true => ActiveAST.new(true)
        }
        options = ["myparam", "MyParam"].collect do |p|
            AST::CaseOpt.new(:value => FakeAST.new(p), :statements => hash[p])
        end
        assert_nothing_raised do
            ast = AST::CaseStatement.new(:test => param, :options => options)
        end

        # Start out case-sensitive
        Puppet[:casesensitive] = true

        result = nil
        assert_nothing_raised do
            result = ast.evaluate :scope => scope
        end
        assert(result, "did not get valid result")
        assert_equal(["upper"], $evaluated, "Did not match case-sensitively")
        assert(! hash["myparam"].evaluated?, "lower value was evaluated even though it did not match")

        # Now try it case-insensitive
        Puppet[:casesensitive] = false
        $evaluated.clear
        hash["MyParam"].reset
        assert_nothing_raised do
            result = ast.evaluate :scope => scope
        end
        assert(result, "did not get valid result")
        assert_equal(["lower"], result, "Did not match case-insensitively")
        assert(! hash["MyParam"].evaluated?, "upper value was evaluated even though it did not match")
    end
end

# $Id$