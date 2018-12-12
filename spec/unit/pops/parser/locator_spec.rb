require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Parser::Locator do

  it "multi byte characters in a comment does not interfere with AST node text extraction" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\nabcdef#XXXXXXXXXX").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.offset).to eq(12)
    expect(model.body.length).to eq(6)
    expect(model.body.locator.extract_text(model.body.offset, model.body.length)).to eq('abcdef')
  end

  it "multi byte characters in a comment does not interfere with AST node text extraction" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\n1 + 2#XXXXXXXXXX").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.offset).to eq(14) # The '+'
    expect(model.body.length).to eq(1)
    expect(model.body.locator.extract_tree_text(model.body)).to eq('1 + 2')
  end

  it 'Locator caches last offset / line' do
    #Puppet::Pops::Parser::Locator::AbstractLocator.expects(:ary_bsearch_i).once
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a\n = 1\n + 1\n").model
    model.body.locator.expects(:ary_bsearch_i).with(anything, 2).once.returns(:special_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:special_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:special_value)
  end

  it 'Locator invalidates last offset / line cache if asked for different offset' do
    #Puppet::Pops::Parser::Locator::AbstractLocator.expects(:ary_bsearch_i).once
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a\n = 1\n + 1\n").model
    model.body.locator.expects(:ary_bsearch_i).with(anything, 2).twice.returns(:first_value, :third_value)
    model.body.locator.expects(:ary_bsearch_i).with(anything, 3).once.returns(:second_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:first_value)
    expect(model.body.locator.line_for_offset(3)).to eq(:second_value) # invalidates cache as side effect
    expect(model.body.locator.line_for_offset(2)).to eq(:third_value)
  end

end
