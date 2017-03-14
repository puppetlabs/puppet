require 'spec_helper'
require 'puppet/pops'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module EppParserRspecHelper
  include FactoryRspecHelper
  def parse(code)
    parser = Puppet::Pops::Parser::EppParser.new()
    parser.parse_string(code)
  end
end

describe "epp parser" do
  include EppParserRspecHelper

  it "should instantiate an epp parser" do
    parser = Puppet::Pops::Parser::EppParser.new()
    expect(parser.class).to eq(Puppet::Pops::Parser::EppParser)
  end

  it "should parse a code string and return a program with epp" do
    parser = Puppet::Pops::Parser::EppParser.new()
    model = parser.parse_string("Nothing to see here, move along...").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::LambdaExpression)
    expect(model.body.body.class).to eq(Puppet::Pops::Model::EppExpression)
  end

  context "when facing bad input it reports" do
    it "unbalanced tags" do
      expect { dump(parse("<% missing end tag")) }.to raise_error(/Unbalanced/)
    end

    it "abrupt end" do
      expect { dump(parse("dum di dum di dum <%")) }.to raise_error(/Unbalanced/)
    end

    it "nested epp tags" do
      expect { dump(parse("<% $a = 10 <% $b = 20 %>%>")) }.to raise_error(/Syntax error/)
    end

    it "nested epp expression tags" do
      expect { dump(parse("<%= 1+1 <%= 2+2 %>%>")) }.to raise_error(/Syntax error/)
    end

    it "rendering sequence of expressions" do
      expect { dump(parse("<%= 1 2 3 %>")) }.to raise_error(/Syntax error/)
    end
  end

  context "handles parsing of" do
    it "text (and nothing else)" do
      expect(dump(parse("Hello World"))).to eq([
        "(lambda (epp (block",
        "  (render-s 'Hello World')",
        ")))"].join("\n"))
    end

    it "template parameters" do
      expect(dump(parse("<%|$x|%>Hello World"))).to eq([
        "(lambda (parameters x) (epp (block",
        "  (render-s 'Hello World')",
        ")))"].join("\n"))
    end

    it "template parameters with default" do
      expect(dump(parse("<%|$x='cigar'|%>Hello World"))).to eq([
        "(lambda (parameters (= x 'cigar')) (epp (block",
        "  (render-s 'Hello World')",
        ")))"].join("\n"))
    end

    it "template parameters with and without default" do
      expect(dump(parse("<%|$x='cigar', $y|%>Hello World"))).to eq([
        "(lambda (parameters (= x 'cigar') y) (epp (block",
        "  (render-s 'Hello World')",
        ")))"].join("\n"))
    end

    it "template parameters + additional setup" do
      expect(dump(parse("<%|$x| $y = 10 %>Hello World"))).to eq([ 
        "(lambda (parameters x) (epp (block",
        "  (= $y 10)",
        "  (render-s 'Hello World')",
        ")))"].join("\n"))
    end

    it "comments" do
      expect(dump(parse("<%#($x='cigar', $y)%>Hello World"))).to eq([
        "(lambda (epp (block",
        "  (render-s 'Hello World')",
        ")))"
        ].join("\n"))
    end

    it "verbatim epp tags" do
      expect(dump(parse("<%% contemplating %%>Hello World"))).to eq([
        "(lambda (epp (block",
        "  (render-s '<% contemplating %>Hello World')",
        ")))"
        ].join("\n"))
    end

    it "expressions" do
      expect(dump(parse("We all live in <%= 3.14 - 2.14 %> world"))).to eq([
        "(lambda (epp (block",
        "  (render-s 'We all live in ')",
        "  (render (- 3.14 2.14))",
        "  (render-s ' world')",
        ")))"
      ].join("\n"))
    end
  end
end
