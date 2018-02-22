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
      expect(var('a').model.class).to eq(Puppet::Pops::Model::VariableExpression)
    end

    it "tests #fqn should create a QualifiedName" do
      expect(fqn('a').model.class).to eq(Puppet::Pops::Model::QualifiedName)
    end

    it "tests #QNAME should create a QualifiedName" do
      expect(QNAME('a').model.class).to eq(Puppet::Pops::Model::QualifiedName)
    end

    it "tests #QREF should create a QualifiedReference" do
      expect(QREF('a').model.class).to eq(Puppet::Pops::Model::QualifiedReference)
    end

    it "tests #block should create a BlockExpression" do
      expect(block().model.is_a?(Puppet::Pops::Model::BlockExpression)).to eq(true)
    end

    it "should create a literal undef on :undef" do
      expect(literal(:undef).model.class).to eq(Puppet::Pops::Model::LiteralUndef)
    end

    it "should create a literal default on :default" do
      expect(literal(:default).model.class).to eq(Puppet::Pops::Model::LiteralDefault)
    end
  end

  context "When calling block_or_expression" do
    it "A single expression should produce identical output" do
      expect(block_or_expression([literal(1) + literal(2)]).model.is_a?(Puppet::Pops::Model::ArithmeticExpression)).to eq(true)
    end

    it "Multiple expressions should produce a block expression" do
      braces = mock 'braces'
      braces.stubs(:offset).returns(0)
      braces.stubs(:length).returns(0)

      model = block_or_expression([literal(1) + literal(2), literal(2) + literal(3)], braces, braces).model
      expect(model.is_a?(Puppet::Pops::Model::BlockExpression)).to eq(true)
      expect(model.statements.size).to eq(2)
    end
  end

  context "When processing calls with CALL_NAMED" do
    it "Should be possible to state that r-value is required" do
      built = call_named('foo', true).model
      expect(built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression)).to eq(true)
      expect(built.rval_required).to eq(true)
    end

    it "Should produce a call expression without arguments" do
      built = call_named('foo', false).model
      expect(built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression)).to eq(true)
      expect(built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName)).to eq(true)
      expect(built.functor_expr.value).to eq("foo")
      expect(built.rval_required).to eq(false)
      expect(built.arguments.size).to eq(0)
    end

    it "Should produce a call expression with one argument" do
      built = call_named('foo', false, literal(1) + literal(2)).model
      expect(built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression)).to eq(true)
      expect(built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName)).to eq(true)
      expect(built.functor_expr.value).to eq("foo")
      expect(built.rval_required).to eq(false)
      expect(built.arguments.size).to eq(1)
      expect(built.arguments[0].is_a?(Puppet::Pops::Model::ArithmeticExpression)).to eq(true)
    end

    it "Should produce a call expression with two arguments" do
      built = call_named('foo', false, literal(1) + literal(2), literal(1) + literal(2)).model
      expect(built.is_a?(Puppet::Pops::Model::CallNamedFunctionExpression)).to eq(true)
      expect(built.functor_expr.is_a?(Puppet::Pops::Model::QualifiedName)).to eq(true)
      expect(built.functor_expr.value).to eq("foo")
      expect(built.rval_required).to eq(false)
      expect(built.arguments.size).to eq(2)
      expect(built.arguments[0].is_a?(Puppet::Pops::Model::ArithmeticExpression)).to eq(true)
      expect(built.arguments[1].is_a?(Puppet::Pops::Model::ArithmeticExpression)).to eq(true)
    end
  end

  context "When creating attribute operations" do
    it "Should produce an attribute operation for =>" do
      built = ATTRIBUTE_OP('aname', '=>', literal('x')).model
      built.is_a?(Puppet::Pops::Model::AttributeOperation)
      expect(built.operator).to eq('=>')
      expect(built.attribute_name).to eq("aname")
      expect(built.value_expr.is_a?(Puppet::Pops::Model::LiteralString)).to eq(true)
    end

    it "Should produce an attribute operation for +>" do
      built = ATTRIBUTE_OP('aname', '+>', literal('x')).model
      built.is_a?(Puppet::Pops::Model::AttributeOperation)
      expect(built.operator).to eq('+>')
      expect(built.attribute_name).to eq("aname")
      expect(built.value_expr.is_a?(Puppet::Pops::Model::LiteralString)).to eq(true)
    end
  end

  context "When processing RESOURCE" do
    it "Should create a Resource body" do
      built = RESOURCE_BODY(literal('title'), [ATTRIBUTE_OP('aname', '=>', literal('x'))]).model
      expect(built.is_a?(Puppet::Pops::Model::ResourceBody)).to eq(true)
      expect(built.title.is_a?(Puppet::Pops::Model::LiteralString)).to eq(true)
      expect(built.operations.size).to eq(1)
      expect(built.operations[0].class).to eq(Puppet::Pops::Model::AttributeOperation)
      expect(built.operations[0].attribute_name).to eq('aname')
    end

    it "Should create a RESOURCE without a resource body" do
      bodies = []
      built = RESOURCE(literal('rtype'), bodies).model
      expect(built.class).to eq(Puppet::Pops::Model::ResourceExpression)
      expect(built.bodies.size).to eq(0)
    end

    it "Should create a RESOURCE with 1 resource body" do
      bodies = [] << RESOURCE_BODY(literal('title'), [])
      built = RESOURCE(literal('rtype'), bodies).model
      expect(built.class).to eq(Puppet::Pops::Model::ResourceExpression)
      expect(built.bodies.size).to eq(1)
      expect(built.bodies[0].title.value).to eq('title')
    end

    it "Should create a RESOURCE with 2 resource bodies" do
      bodies = [] << RESOURCE_BODY(literal('title'), []) << RESOURCE_BODY(literal('title2'), [])
      built = RESOURCE(literal('rtype'), bodies).model
      expect(built.class).to eq(Puppet::Pops::Model::ResourceExpression)
      expect(built.bodies.size).to eq(2)
      expect(built.bodies[0].title.value).to eq('title')
      expect(built.bodies[1].title.value).to eq('title2')
    end
  end

  context "When processing simple literals" do
    it "Should produce a literal boolean from a boolean" do
      model = literal(true).model
      expect(model.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(model.value).to eq(true)
      model = literal(false).model
      expect(model.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(model.value).to eq(false)
    end
  end

  context "When processing COLLECT" do
    it "should produce a virtual query" do
      model = VIRTUAL_QUERY(fqn('a').eq(literal(1))).model
      expect(model.class).to eq(Puppet::Pops::Model::VirtualQuery)
      expect(model.expr.class).to eq(Puppet::Pops::Model::ComparisonExpression)
      expect(model.expr.operator).to eq('==')
    end

    it "should produce an export query" do
      model = EXPORTED_QUERY(fqn('a').eq(literal(1))).model
      expect(model.class).to eq(Puppet::Pops::Model::ExportedQuery)
      expect(model.expr.class).to eq(Puppet::Pops::Model::ComparisonExpression)
      expect(model.expr.operator).to eq('==')
    end

    it "should produce a collect expression" do
      q = VIRTUAL_QUERY(fqn('a').eq(literal(1)))
      built = COLLECT(literal('t'), q, [ATTRIBUTE_OP('name', '=>', literal(3))]).model
      expect(built.class).to eq(Puppet::Pops::Model::CollectExpression)
      expect(built.operations.size).to eq(1)
    end

    it "should produce a collect expression without attribute operations" do
      q = VIRTUAL_QUERY(fqn('a').eq(literal(1)))
      built = COLLECT(literal('t'), q, []).model
      expect(built.class).to eq(Puppet::Pops::Model::CollectExpression)
      expect(built.operations.size).to eq(0)
    end
  end

  context "When processing concatenated string(iterpolation)" do
    it "should handle 'just a string'" do
      model = string('blah blah').model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      expect(model.segments.size).to eq(1)
      expect(model.segments[0].class).to eq(Puppet::Pops::Model::LiteralString)
      expect(model.segments[0].value).to eq("blah blah")
    end

    it "should handle one expression in the middle" do
      model = string('blah blah', TEXT(literal(1)+literal(2)), 'blah blah').model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      expect(model.segments.size).to eq(3)
      expect(model.segments[0].class).to eq(Puppet::Pops::Model::LiteralString)
      expect(model.segments[0].value).to eq("blah blah")
      expect(model.segments[1].class).to eq(Puppet::Pops::Model::TextExpression)
      expect(model.segments[1].expr.class).to eq(Puppet::Pops::Model::ArithmeticExpression)
      expect(model.segments[2].class).to eq(Puppet::Pops::Model::LiteralString)
      expect(model.segments[2].value).to eq("blah blah")
    end

    it "should handle one expression at the end" do
      model = string('blah blah', TEXT(literal(1)+literal(2))).model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      expect(model.segments.size).to eq(2)
      expect(model.segments[0].class).to eq(Puppet::Pops::Model::LiteralString)
      expect(model.segments[0].value).to eq("blah blah")
      expect(model.segments[1].class).to eq(Puppet::Pops::Model::TextExpression)
      expect(model.segments[1].expr.class).to eq(Puppet::Pops::Model::ArithmeticExpression)
    end

    it "should handle only one expression" do
      model = string(TEXT(literal(1)+literal(2))).model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      expect(model.segments.size).to eq(1)
      expect(model.segments[0].class).to eq(Puppet::Pops::Model::TextExpression)
      expect(model.segments[0].expr.class).to eq(Puppet::Pops::Model::ArithmeticExpression)
    end

    it "should handle several expressions" do
      model = string(TEXT(literal(1)+literal(2)), TEXT(literal(1)+literal(2))).model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      expect(model.segments.size).to eq(2)
      expect(model.segments[0].class).to eq(Puppet::Pops::Model::TextExpression)
      expect(model.segments[0].expr.class).to eq(Puppet::Pops::Model::ArithmeticExpression)
      expect(model.segments[1].class).to eq(Puppet::Pops::Model::TextExpression)
      expect(model.segments[1].expr.class).to eq(Puppet::Pops::Model::ArithmeticExpression)
    end

    it "should handle no expression" do
      model = string().model
      expect(model.class).to eq(Puppet::Pops::Model::ConcatenatedString)
      model.segments.size == 0
    end
  end

  context "When processing UNLESS" do
    it "should create an UNLESS expression with then part" do
      built = UNLESS(literal(true), literal(1), literal(nil)).model
      expect(built.class).to eq(Puppet::Pops::Model::UnlessExpression)
      expect(built.test.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(built.then_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
      expect(built.else_expr.class).to eq(Puppet::Pops::Model::Nop)
    end

    it "should create an UNLESS expression with then and else parts" do
      built = UNLESS(literal(true), literal(1), literal(2)).model
      expect(built.class).to eq(Puppet::Pops::Model::UnlessExpression)
      expect(built.test.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(built.then_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
      expect(built.else_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
    end
  end

  context "When processing IF" do
    it "should create an IF expression with then part" do
      built = IF(literal(true), literal(1), literal(nil)).model
      expect(built.class).to eq(Puppet::Pops::Model::IfExpression)
      expect(built.test.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(built.then_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
      expect(built.else_expr.class).to eq(Puppet::Pops::Model::Nop)
    end

    it "should create an IF expression with then and else parts" do
      built = IF(literal(true), literal(1), literal(2)).model
      expect(built.class).to eq(Puppet::Pops::Model::IfExpression)
      expect(built.test.class).to eq(Puppet::Pops::Model::LiteralBoolean)
      expect(built.then_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
      expect(built.else_expr.class).to eq(Puppet::Pops::Model::LiteralInteger)
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
