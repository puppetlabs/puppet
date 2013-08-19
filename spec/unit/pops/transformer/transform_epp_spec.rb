#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/factory_rspec_helper'

module EppTransformerRspecHelper
  include FactoryRspecHelper
  # Dumps the AST to string form
  #
  def astdump(ast)
    ast = transform(ast) unless ast.kind_of?(Puppet::Parser::AST)
    Puppet::Pops::Model::AstTreeDumper.new.dump(ast)
  end

  # Transforms the Pops model to an AST model
  #
  def transform(model)
    Puppet::Pops::Model::AstTransformer.new.transform(model)
  end

  # Parses the string code to a Pops model
  #
  def parse(code)
    parser = Puppet::Pops::Parser::EppParser.new()
    parser.parse_string(code)
  end
end

describe "ast transformer when transforming epp" do
  include EppTransformerRspecHelper

  context "handles transformation of" do
    it "text (and nothing else)" do
      astdump(parse("Hello World")).should == "(epp (block (render-s 'Hello World')))"
    end

    it "template parameters" do
      astdump(parse("<%($x)%>Hello World")).should == "(epp (parameters x) (block (render-s 'Hello World')))"
    end

    it "template parameters with default" do
      astdump(parse("<%($x='cigar')%>Hello World")).should == "(epp (parameters (= x 'cigar')) (block (render-s 'Hello World')))"
    end

    it "template parameters with and without default" do
      astdump(parse("<%($x='cigar', $y)%>Hello World")).should == "(epp (parameters (= x 'cigar') y) (block (render-s 'Hello World')))"
    end

    it "comments" do
      astdump(parse("<%#($x='cigar', $y)%>Hello World")).should == "(epp (block (render-s 'Hello World')))"
    end

    it "verbatim epp tags" do
      astdump(parse("<%% contemplating %%>Hello World")).should == "(epp (block (render-s '<% contemplating %>Hello World')))"
    end

    it "expressions" do
      astdump(parse("We all live in <%= 3.14 - 2.14 %> world")).should ==
        "(epp (block (render-s 'We all live in ') (render (- 3.14 2.14)) (render-s ' world')))"
    end
  end
end
