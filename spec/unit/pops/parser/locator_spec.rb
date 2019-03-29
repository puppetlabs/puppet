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
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a\n = 1\n + 1\n").model
    expect(model.body.locator).to receive(:ary_bsearch_i).with(anything, 2).once.and_return(:special_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:special_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:special_value)
  end

  it 'Locator invalidates last offset / line cache if asked for different offset' do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a\n = 1\n + 1\n").model
    expect(model.body.locator).to receive(:ary_bsearch_i).with(anything, 2).twice.and_return(:first_value, :third_value)
    expect(model.body.locator).to receive(:ary_bsearch_i).with(anything, 3).once.and_return(:second_value)
    expect(model.body.locator.line_for_offset(2)).to eq(:first_value)
    expect(model.body.locator.line_for_offset(3)).to eq(:second_value) # invalidates cache as side effect
    expect(model.body.locator.line_for_offset(2)).to eq(:third_value)
  end

  it 'A heredoc without margin and interpolated expression location has offset and length relative the source' do
    parser = Puppet::Pops::Parser::Parser.new()
    src = <<-CODE
    # line one
    # line two
    @("END"/L)
        Line four\\
        Line five ${1 +
        1}
    END
    CODE

    model = parser.parse_string(src).model
    interpolated_expr = model.body.text_expr.segments[1].expr
    expect(interpolated_expr.left_expr.offset).to eq(84)
    expect(interpolated_expr.left_expr.length).to eq(1)
    expect(interpolated_expr.right_expr.offset).to eq(96)
    expect(interpolated_expr.right_expr.length).to eq(1)
    expect(interpolated_expr.offset).to eq(86) # the + sign
    expect(interpolated_expr.length).to eq(1) # the + sign
    expect(interpolated_expr.locator.extract_tree_text(interpolated_expr)).to eq("1 +\n        1")
  end

  it 'A heredoc with margin and interpolated expression location has offset and length relative the source' do
    parser = Puppet::Pops::Parser::Parser.new()
    src = <<-CODE
    # line one
    # line two
    @("END"/L)
        Line four\\
        Line five ${1 +
        1}
    |- END
    CODE

    model = parser.parse_string(src).model
    interpolated_expr = model.body.text_expr.segments[1].expr
    expect(interpolated_expr.left_expr.offset).to eq(84)
    expect(interpolated_expr.left_expr.length).to eq(1)
    expect(interpolated_expr.right_expr.offset).to eq(96)
    expect(interpolated_expr.right_expr.length).to eq(1)
    expect(interpolated_expr.offset).to eq(86) # the + sign
    expect(interpolated_expr.length).to eq(1) # the + sign
    expect(interpolated_expr.locator.extract_tree_text(interpolated_expr)).to eq("1 +\n        1")
  end
end
