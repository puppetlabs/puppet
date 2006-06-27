#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'test/unit'
require 'puppettest'

class TestLangFunctions < Test::Unit::TestCase
	include ParserTesting
    def test_functions
        assert_raise(Puppet::ParseError) do
            Puppet::Parser::AST::Function.new(
                :name => "fakefunction",
                :arguments => AST::ASTArray.new(
                    :children => [nameobj("avalue")]
                )
            )
        end

        assert_nothing_raised do
            Puppet::Parser::Functions.newfunction(:fakefunction, :rvalue) do |input|
                return "output %s" % input[0]
            end
        end

        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "fakefunction",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [nameobj("avalue")]
                )
            )
        end

        scope = Puppet::Parser::Scope.new()
        val = nil
        assert_nothing_raised do
            val = func.evaluate(:scope => scope)
        end

        assert_equal("output avalue", val)
    end

    def test_taggedfunction
        scope = Puppet::Parser::Scope.new()

        tag = "yayness"
        scope.setclass(tag.object_id, tag)

        {"yayness" => true, "booness" => false}.each do |tag, retval|
            func = taggedobj(tag, :rvalue)

            val = nil
            assert_nothing_raised do
                val = func.evaluate(:scope => scope)
            end

            assert_equal(retval, val, "'tagged' returned %s for %s" % [val, tag])
        end
    end

    def test_failfunction
        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "fail",
                :ftype => :statement,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj("this is a failure")]
                )
            )
        end

        scope = Puppet::Parser::Scope.new()
        val = nil
        assert_raise(Puppet::ParseError) do
            val = func.evaluate(:scope => scope)
        end
    end
end

# $Id$
