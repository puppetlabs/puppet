#!/usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/parsertesting'

class TestVariable < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::ParserTesting
  AST = Puppet::Parser::AST

  def setup
    super
    @scope = mkscope
    @name = "myvar"
    @var = AST::Variable.new(:value => @name)
  end

  def test_evaluate
    assert_equal(:undef, @var.evaluate(@scope), "did not return :undef on unset var")
    @scope.setvar(@name, "something")
    assert_equal("something", @var.evaluate(@scope), "incorrect variable value")
  end
end

