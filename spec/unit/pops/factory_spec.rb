#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require File.join(File.dirname(__FILE__), '/factory_rspec_helper')

# This file contains testing of the pops model factory
#

describe Puppet::Pops::Model::Factory do
  include FactoryRspecHelper

  context "When factory methods are invoked they should produce expected results" do
    it "tests #var should create a VariableExpression" do
      var('a').current.class.should == Puppet::Pops::Model::VariableExpression
    end

    it "tests #fqn should create a QualifiedName" do
      fqn('a').current.class.should == Puppet::Pops::Model::QualifiedName
    end

    it "tests #QNAME should create a QualifiedName" do
      QNAME('a').current.class.should == Puppet::Pops::Model::QualifiedName
    end

    it "tests #QREF should create a QualifiedReference" do
      QREF('a').current.class.should == Puppet::Pops::Model::QualifiedReference
    end

    it "tests #block should create a BlockExpression" do
      block().current.is_a?(Puppet::Pops::Model::BlockExpression).should == true
    end

    it "should create a literal undef on :undef" do
      literal(:undef).current.class.should == Puppet::Pops::Model::LiteralUndef
    end

    it "should create a literal default on :default" do
      literal(:default).current.class.should == Puppet::Pops::Model::LiteralDefault
    end
  end

  context "When calling block_or_expression" do
    it "A single expression should produce identical output" do
      block_or_expression(literal(1) + literal(2)).current.is_a?(Puppet::Pops::Model::ArithmeticExpression).should == true
    end

    it "Multiple expressions should produce a block expression" do
      built = block_or_expression(literal(1) + literal(2), literal(2) + literal(3)).current
      built.is_a?(Puppet::Pops::Model::BlockExpression).should == true
      built.statements.size.should == 2
    end
  end

  context "When processing calls with CALL_NAMED" do
    it "Should be possible to state that r-value is required" do
      built = CALL_NAMED("foo", true, []).current
      built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression).should == true
      built.rval_required.should == true
    end

    it "Should produce a call expression without arguments" do
      built = CALL_NAMED("foo", false, []).current
      built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression).should == true
      built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName).should == true
      built.functor_expr.value.should == "foo"
      built.rval_required.should == false
      built.arguments.size.should == 0
    end

    it "Should produce a call expression with one argument" do
      built = CALL_NAMED("foo", false, [literal(1) + literal(2)]).current
      built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression).should == true
      built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName).should == true
      built.functor_expr.value.should == "foo"
      built.rval_required.should == false
      built.arguments.size.should == 1
      built.arguments[0].is_a?(Puppet::Pops::Model::ArithmeticExpression).should == true
    end

    it "Should produce a call expression with two arguments" do
      built = CALL_NAMED("foo", false, [literal(1) + literal(2), literal(1) + literal(2)]).current
      built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression).should == true
      built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName).should == true
      built.functor_expr.value.should == "foo"
      built.rval_required.should == false
      built.arguments.size.should == 2
      built.arguments[0].is_a?(Puppet::Pops::Model::ArithmeticExpression).should == true
      built.arguments[1].is_a?(Puppet::Pops::Model::ArithmeticExpression).should == true
    end
  end

  context "When creating attribute operations" do
    it "Should produce an attribute operation for =>" do
      built = ATTRIBUTE_OP("aname", :'=>', 'x').current
      built.is_a?(Puppet::Pops::Model::AttributeOperation)
      built.operator.should == :'=>'
      built.attribute_name.should == "aname"
      built.value_expr.is_a?(Puppet::Pops::Model::LiteralString).should == true
    end

    it "Should produce an attribute operation for +>" do
      built = ATTRIBUTE_OP("aname", :'+>', 'x').current
      built.is_a?(Puppet::Pops::Model::AttributeOperation)
      built.operator.should == :'+>'
      built.attribute_name.should == "aname"
      built.value_expr.is_a?(Puppet::Pops::Model::LiteralString).should == true
    end
  end

  context "When processing RESOURCE" do
    it "Should create a Resource body" do
      built = RESOURCE_BODY("title", [ATTRIBUTE_OP('aname', :'=>', 'x')]).current
      built.is_a?(Puppet::Pops::Model::ResourceBody).should == true
      built.title.is_a?(Puppet::Pops::Model::LiteralString).should == true
      built.operations.size.should == 1
      built.operations[0].class.should == Puppet::Pops::Model::AttributeOperation
      built.operations[0].attribute_name.should == 'aname'
    end

    it "Should create a RESOURCE without a resource body" do
      bodies = []
      built = RESOURCE("rtype", bodies).current
      built.class.should == Puppet::Pops::Model::ResourceExpression
      built.bodies.size.should == 0
    end

    it "Should create a RESOURCE with 1 resource body" do
      bodies = [] << RESOURCE_BODY('title', [])
      built = RESOURCE("rtype", bodies).current
      built.class.should == Puppet::Pops::Model::ResourceExpression
      built.bodies.size.should == 1
      built.bodies[0].title.value.should == 'title'
    end

    it "Should create a RESOURCE with 2 resource bodies" do
      bodies = [] << RESOURCE_BODY('title', []) << RESOURCE_BODY('title2', [])
      built = RESOURCE("rtype", bodies).current
      built.class.should == Puppet::Pops::Model::ResourceExpression
      built.bodies.size.should == 2
      built.bodies[0].title.value.should == 'title'
      built.bodies[1].title.value.should == 'title2'
    end
  end

  context "When processing simple literals" do
    it "Should produce a literal boolean from a boolean" do
      built = literal(true).current
      built.class.should == Puppet::Pops::Model::LiteralBoolean
      built.value.should == true
      built = literal(false).current
      built.class.should == Puppet::Pops::Model::LiteralBoolean
      built.value.should == false
    end
  end

  context "When processing COLLECT" do
    it "should produce a virtual query" do
      built = VIRTUAL_QUERY(fqn('a') == literal(1)).current
      built.class.should == Puppet::Pops::Model::VirtualQuery
      built.expr.class.should == Puppet::Pops::Model::ComparisonExpression
      built.expr.operator.should ==  :'=='
    end

    it "should produce an export query" do
      built = EXPORTED_QUERY(fqn('a') == literal(1)).current
      built.class.should == Puppet::Pops::Model::ExportedQuery
      built.expr.class.should == Puppet::Pops::Model::ComparisonExpression
      built.expr.operator.should ==  :'=='
    end

    it "should produce a collect expression" do
      q = VIRTUAL_QUERY(fqn('a') == literal(1))
      built = COLLECT(literal('t'), q, [ATTRIBUTE_OP('name', :'=>', 3)]).current
      built.class.should == Puppet::Pops::Model::CollectExpression
      built.operations.size.should == 1
    end

    it "should produce a collect expression without attribute operations" do
      q = VIRTUAL_QUERY(fqn('a') == literal(1))
      built = COLLECT(literal('t'), q, []).current
      built.class.should == Puppet::Pops::Model::CollectExpression
      built.operations.size.should == 0
    end
  end

  context "When processing concatenated string(iterpolation)" do
    it "should handle 'just a string'" do
      built = string('blah blah').current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 1
      built.segments[0].class.should == Puppet::Pops::Model::LiteralString
      built.segments[0].value.should == "blah blah"
    end

    it "should handle one expression in the middle" do
      built = string('blah blah', TEXT(literal(1)+literal(2)), 'blah blah').current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 3
      built.segments[0].class.should == Puppet::Pops::Model::LiteralString
      built.segments[0].value.should == "blah blah"
      built.segments[1].class.should == Puppet::Pops::Model::TextExpression
      built.segments[1].expr.class.should == Puppet::Pops::Model::ArithmeticExpression
      built.segments[2].class.should == Puppet::Pops::Model::LiteralString
      built.segments[2].value.should == "blah blah"
    end

    it "should handle one expression at the end" do
      built = string('blah blah', TEXT(literal(1)+literal(2))).current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 2
      built.segments[0].class.should == Puppet::Pops::Model::LiteralString
      built.segments[0].value.should == "blah blah"
      built.segments[1].class.should == Puppet::Pops::Model::TextExpression
      built.segments[1].expr.class.should == Puppet::Pops::Model::ArithmeticExpression
    end

    it "should handle only one expression" do
      built = string(TEXT(literal(1)+literal(2))).current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 1
      built.segments[0].class.should == Puppet::Pops::Model::TextExpression
      built.segments[0].expr.class.should == Puppet::Pops::Model::ArithmeticExpression
    end

    it "should handle several expressions" do
      built = string(TEXT(literal(1)+literal(2)), TEXT(literal(1)+literal(2))).current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 2
      built.segments[0].class.should == Puppet::Pops::Model::TextExpression
      built.segments[0].expr.class.should == Puppet::Pops::Model::ArithmeticExpression
      built.segments[1].class.should == Puppet::Pops::Model::TextExpression
      built.segments[1].expr.class.should == Puppet::Pops::Model::ArithmeticExpression
    end

    it "should handle no expression" do
      built = string().current
      built.class.should == Puppet::Pops::Model::ConcatenatedString
      built.segments.size == 0
    end
  end

  context "When processing UNLESS" do
    it "should create an UNLESS expression with then part" do
      built = UNLESS(true, literal(1), nil).current
      built.class.should == Puppet::Pops::Model::UnlessExpression
      built.test.class.should == Puppet::Pops::Model::LiteralBoolean
      built.then_expr.class.should == Puppet::Pops::Model::LiteralInteger
      built.else_expr.class.should == Puppet::Pops::Model::Nop
    end

    it "should create an UNLESS expression with then and else parts" do
      built = UNLESS(true, literal(1), literal(2)).current
      built.class.should == Puppet::Pops::Model::UnlessExpression
      built.test.class.should == Puppet::Pops::Model::LiteralBoolean
      built.then_expr.class.should == Puppet::Pops::Model::LiteralInteger
      built.else_expr.class.should == Puppet::Pops::Model::LiteralInteger
    end
  end

  context "When processing IF" do
    it "should create an IF expression with then part" do
      built = IF(true, literal(1), nil).current
      built.class.should == Puppet::Pops::Model::IfExpression
      built.test.class.should == Puppet::Pops::Model::LiteralBoolean
      built.then_expr.class.should == Puppet::Pops::Model::LiteralInteger
      built.else_expr.class.should == Puppet::Pops::Model::Nop
    end

    it "should create an IF expression with then and else parts" do
      built = IF(true, literal(1), literal(2)).current
      built.class.should == Puppet::Pops::Model::IfExpression
      built.test.class.should == Puppet::Pops::Model::LiteralBoolean
      built.then_expr.class.should == Puppet::Pops::Model::LiteralInteger
      built.else_expr.class.should == Puppet::Pops::Model::LiteralInteger
    end
  end

  context "When processing a Parameter" do
    it "should create a Parameter" do
      # PARAM(name, expr)
      # PARAM(name)
      #
    end
  end

  # LIST, HASH, KEY_ENTRY
  context "When processing Definition" do
    # DEFINITION(classname, arguments, statements)
    # should accept empty arguments, and no statements
  end

  context "When processing Hostclass" do
    # HOSTCLASS(classname, arguments, parent, statements)
    # parent may be passed as a nop /nil - check this works, should accept empty statements (nil)
    # should accept empty arguments

  end

  context "When processing Node" do
  end

  # Tested in the evaluator test already, but should be here to test factory assumptions
  #
  # TODO: CASE / WHEN
  # TODO: MAP
end
