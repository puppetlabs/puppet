#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/impl'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

# This file contains testing of variables in a top scope and named scopes.
#
describe Puppet::Pops::Impl::EvaluatorImpl do
  include EvaluatorRspecHelper

  context "When the evaluator deals with type creation" do
    context "it should handle" do
      it "A simple type with one attribute" do
        pending "Test is UNFINISHED"

        type_expr = TYPE('MyType').attributes(ATTR('name'))
        puts "type_creation_spec.rb UNFINISHED"
        puts evaluate(type_expr)
      end
#      it "local scope shadows top scope and fqn set in top scope" do
#        top_scope_block   = block( fqn('a').set(literal(2)+literal(2)), var('a'))
#        local_scope_block = block( fqn('a').set(var('a') + literal(2)), var('a'))
#        evaluate(top_scope_block, "x", local_scope_block) do |scope|
#          scope.get_variable_entry("x::a").value.should == 6
#        end.should == 6
#      end
    end
  end
end
