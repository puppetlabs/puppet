#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'puppet/parser/parser'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'

class TestAST < Test::Unit::TestCase
  include PuppetTest::ParserTesting
  include PuppetTest::ResourceTesting

  def test_if
    scope = mkscope
    astif = nil
    astelse = nil
    fakeelse = FakeAST.new(:else)
    faketest = FakeAST.new(true)
    fakeif = FakeAST.new(:if)

    assert_nothing_raised {
      astelse = AST::Else.new(:statements => fakeelse)
    }
    assert_nothing_raised {

            astif = AST::IfStatement.new(
                
        :test => faketest,
        :statements => fakeif,
        
        :else => astelse
      )
    }

    # We initialized it to true, so we should get that first
    ret = nil
    assert_nothing_raised {
      ret = astif.evaluate(scope)
    }
    assert_equal(:if, ret)

    # Now set it to false and check that
    faketest.evaluate = false
    assert_nothing_raised {
      ret = astif.evaluate(scope)
    }
    assert_equal(:else, ret)
  end

  # Make sure our override object behaves "correctly"
  def test_override
    scope = mkscope

    ref = nil
    assert_nothing_raised do
      ref = resourceoverride("file", "/yayness", "owner" => "blah", "group" => "boo")
    end

    scope.compiler.expects(:add_override).with { |res| res.is_a?(Puppet::Parser::Resource) }
    ret = nil
    assert_nothing_raised do
      ret = ref.evaluate scope
    end

    assert_instance_of(Puppet::Parser::Resource, ret, "Did not return override")
  end

  def test_collection
    scope = mkscope

    coll = nil
    assert_nothing_raised do
      coll = AST::Collection.new(:type => "file", :form => :virtual)
    end

    assert_instance_of(AST::Collection, coll)

    ret = nil
    assert_nothing_raised do
      ret = coll.evaluate scope
    end

    assert_instance_of(Puppet::Parser::Collector, ret)

    # Now make sure we get it back from the scope
    colls = scope.compiler.instance_variable_get("@collections")
    assert_equal([ret], colls, "Did not store collector in config's collection list")
  end
end
