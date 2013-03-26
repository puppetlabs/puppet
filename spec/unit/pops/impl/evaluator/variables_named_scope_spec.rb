#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'
require 'puppet/pops/impl/top_scope'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

# This file contains testing of variables in a top scope and named scopes.
#
describe Puppet::Pops::Impl::EvaluatorImpl do
  include EvaluatorRspecHelper

  context "When the evaluator deals with variables" do
    context "it should handle" do
      it "simple assignment and dereference" do
        evaluate(block( fqn('a').set(literal(2)+literal(2)), var('a'))).should == 4
      end
      it "local scope shadows top scope and fqn set in top scope" do
        top_scope_block   = block( fqn('a').set(literal(2)+literal(2)), var('a'))
        local_scope_block = block( fqn('a').set(var('a') + literal(2)), var('a'))
        evaluate(top_scope_block, "x", local_scope_block) do |scope|
          scope.get_variable_entry("x::a").value.should == 6
        end.should == 6
      end
      context "+= operations" do
        context "appending to list" do
          it "from list, [] += []" do
            top_scope_block = fqn('a').set([1,2,3])
            local_scope_block = fqn('a').plus_set([4])
            evaluate(top_scope_block, "x", local_scope_block) do |scope|
              scope.get_variable_entry("x::a").value.should == [1,2,3,4]
            end.should == [1,2,3,4]
          end
       end
      end
    end
  end
end
