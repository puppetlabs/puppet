#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-12-22.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/parsertesting'

class TestSelector < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
	AST = Puppet::Parser::AST
    
    def test_evaluate
        scope = mkscope
        upperparam = nameobj("MYPARAM")
        lowerparam = nameobj("myparam")
        
        should = {"MYPARAM" => "upper", "myparam" => "lower"}
        
        maker = Proc.new do
            {
            :default => AST::ResourceParam.new(:param => AST::Default.new(:value => "default"), :value => FakeAST.new("default")),
            :lower => AST::ResourceParam.new(:param => FakeAST.new("myparam"), :value => FakeAST.new("lower")),
            :upper => AST::ResourceParam.new(:param => FakeAST.new("MYPARAM"), :value => FakeAST.new("upper")),
            }
            
        end
        
        # Start out case-sensitive
        Puppet[:casesensitive] = true
        
        %w{MYPARAM myparam}.each do |str|
            param = nameobj(str)
            params = maker.call()
            sel = AST::Selector.new(:param => param, :values => params.values)
            result = nil
            assert_nothing_raised { result = sel.evaluate(:scope => scope) }
            assert_equal(should[str], result, "did not case-sensitively match %s" % str)
        end
        
        # then insensitive
        Puppet[:casesensitive] = false
        
        %w{MYPARAM myparam}.each do |str|
            param = nameobj(str)
            params = maker.call()

            # Delete the upper value, since we don't want it to match
            # and it introduces a hash-ordering bug in testing.
            params.delete(:upper)
            sel = AST::Selector.new(:param => param, :values => params.values)
            result = nil
            assert_nothing_raised { result = sel.evaluate(:scope => scope) }
            assert_equal("lower", result, "did not case-insensitively match %s" % str)
        end
    end
end

