require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Parser::Parser do
  it "should instantiate a parser" do
    parser = Puppet::Pops::Parser::Parser.new()
    expect(parser.class).to eq(Puppet::Pops::Parser::Parser)
  end

  it "should parse a code string and return a model" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a = 10").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::AssignmentExpression)
  end

  it "should accept empty input and return a model" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
  end

  it "should accept empty input containing only comments and report location at end of input" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# comment\n").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
    adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(model.body)
    expect(adapter.offset).to eq(10)
    expect(adapter.length).to eq(0)
  end

  it "multi byte characters in a comment are counted as individual bytes" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\n").current
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
    adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(model.body)
    expect(adapter.offset).to eq(12)
    expect(adapter.length).to eq(0)
  end

  it "should raise an error with position information when error is raised from within parser" do
    parser = Puppet::Pops::Parser::Parser.new()
    the_error = nil
    begin
      parser.parse_string("File [1] { }", 'fakefile.pp')
    rescue Puppet::ParseError => e
      the_error = e
    end
    expect(the_error).to be_a(Puppet::ParseError)
    expect(the_error.file).to eq('fakefile.pp')
    expect(the_error.line).to eq(1)
    expect(the_error.pos).to eq(6)
  end

  it "should raise an error with position information when error is raised on token" do
    parser = Puppet::Pops::Parser::Parser.new()
    the_error = nil
    begin
      parser.parse_string(<<-EOF, 'fakefile.pp')
class whoops($a,$b,$c) {
  $d = "oh noes",  "b"
}
      EOF
    rescue Puppet::ParseError => e
      the_error = e
    end
    expect(the_error).to be_a(Puppet::ParseError)
    expect(the_error.file).to eq('fakefile.pp')
    expect(the_error.line).to eq(2)
    expect(the_error.pos).to eq(17)
  end
end
