#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'
require 'puppet/pops/impl/parser/eparser'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

RSpec.configure do |c|
  c.include ParserRspecHelper
end
  
describe Puppet::Pops::Impl::Parser::Parser do
  EvaluationError = Puppet::Pops::EvaluationError
    
  context "When parsing Lists" do
    it "$a = [1, 2, 3][2]" do
      pending "hasharrayaccess only operates on variable as LHS due to clash with resource reference"
      dump(parse("$a = [1,2,3][2]")).should == "(= $a (slice ([] 1 2 3) 2))"
    end
  end
end
