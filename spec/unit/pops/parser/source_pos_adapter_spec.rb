require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Adapters::SourcePosAdapter do

  it "multi byte characters in a comment does not interfere with AST node text extraction" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\nabcdef#XXXXXXXXXX").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(model.body)
    expect(adapter.offset).to eq(12)
    expect(adapter.length).to eq(6)
    expect(adapter.extract_text).to eq('abcdef')
  end

  it "multi byte characters in a comment does not interfere with AST node text extraction" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\n1 + 2#XXXXXXXXXX").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(model.body)
    expect(adapter.offset).to eq(14) # The '+'
    expect(adapter.length).to eq(1)
    expect(adapter.extract_tree_text).to eq('1 + 2')
  end

end
