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

end
