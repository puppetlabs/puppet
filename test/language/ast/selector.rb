#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-12-22.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'

class TestSelector < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
	AST = Puppet::Parser::AST
    
    def test_evaluate
        sel = nil
        scope = mkscope
        param = nameobj("MyParam")

        hash = {
            "myparam" => FakeAST.new("lower"),
            "MyParam" => FakeAST.new("upper")
        }
        values = ["myparam", "MyParam"].collect do |p|
            AST::ResourceParam.new(:param => FakeAST.new(p), :value => hash[p])
        end
        assert_nothing_raised do
            sel = AST::Selector.new(:param => param, :values => values)
        end
        
        # Start out case-sensitive
        Puppet[:casesensitive] = true
        
        result = nil
        assert_nothing_raised do
            result = sel.evaluate :scope => scope
        end
        assert_equal("upper", result, "Did not match case-sensitively")
        assert(! hash["myparam"].evaluated?, "lower value was evaluated even though it did not match")
        
        # Now try it case-insensitive
        Puppet[:casesensitive] = false
        hash["MyParam"].reset
        assert_nothing_raised do
            result = sel.evaluate :scope => scope
        end
        assert_equal("lower", result, "Did not match case-insensitively")
        assert(! hash["MyParam"].evaluated?, "upper value was evaluated even though it did not match")
    end
end

# $Id$