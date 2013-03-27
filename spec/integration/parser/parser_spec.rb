#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/parser_factory'

describe "Puppet::Parser::Parser" do
  module ParseMatcher
    class ParseAs
      def initialize(klass)
        @parser = Puppet::Parser::ParserFactory.parser("development")
        @class = klass
      end

      def result_instance
        @result.code[0]
      end

      def matches?(string)
        @string = string
        @result = @parser.parse(string)
        result_instance.instance_of?(@class)
      end

      def description
        "parse as a #{@class}"
      end

      def failure_message
        " expected #{@string} to parse as #{@class} but was #{result_instance.class}"
      end

      def negative_failure_message
        " expected #{@string} not to parse as #{@class}"
      end
    end

    def parse_as(klass)
      ParseAs.new(klass)
    end

    class ParseWith
      def initialize(block)
        @parser = Puppet::Parser::ParserFactory.parser("development")
        @block = block
      end

      def result_instance
        @result.code[0]
      end

      def matches?(string)
        @string = string
        @result = @parser.parse(string)
        @block.call(result_instance)
      end

      def description
        "parse with the block evaluating to true"
      end

      def failure_message
        " expected #{@string} to parse with a true result in the block"
      end

      def negative_failure_message
        " expected #{@string} not to parse with a true result in the block"
      end
    end

    def parse_with(&block)
      ParseWith.new(block)
    end
  end

  include ParseMatcher

  before :each do
    @resource_type_collection = Puppet::Resource::TypeCollection.new("env")
    @parser = Puppet::Parser::ParserFactory.parser("development")

#    @parser = Puppet::Parser::Parser.new "development"
  end
  shared_examples_for 'a puppet parser' do
    describe "when parsing comments before statement" do
      it "should associate the documentation to the statement AST node" do
        if Puppet[:parser] == 'future'
          pending "egrammar does not yet process comments"
        end
        ast = @parser.parse("""
        # comment
        class test {}
        """)

        ast.code[0].should be_a(Puppet::Parser::AST::Hostclass)
        ast.code[0].name.should == 'test'
        ast.code[0].instantiate('')[0].doc.should == "comment\n"
      end
    end

    describe "when parsing" do
      it "should be able to parse normal left to right relationships" do
        "Notify[foo] -> Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
      end

      it "should be able to parse right to left relationships" do
        "Notify[foo] <- Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
      end

      it "should be able to parse normal left to right subscriptions" do
        "Notify[foo] ~> Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
      end

      it "should be able to parse right to left subscriptions" do
        "Notify[foo] <~ Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
      end

      it "should correctly set the arrow type of a relationship" do
        "Notify[foo] <~ Notify[bar]".should parse_with { |rel| rel.arrow == "<~" }
      end

      it "should be able to parse deep hash access" do
        %q{
          $hash = { 'a' => { 'b' => { 'c' => 'it works' } } }
          $out = $hash['a']['b']['c']
        }.should parse_with { |v| v.value.is_a?(Puppet::Parser::AST::ASTHash) }
      end

      it "should fail if asked to parse '$foo::::bar'" do
        expect { @parser.parse("$foo::::bar") }.to raise_error(Puppet::ParseError, /Syntax error at ':'/)
      end

      describe "function calls" do
        it "should be able to pass an array to a function" do
          "my_function([1,2,3])".should parse_with { |fun|
            fun.is_a?(Puppet::Parser::AST::Function) &&
            fun.arguments[0].evaluate(stub 'scope') == ['1','2','3']
          }
        end

        it "should be able to pass a hash to a function" do
          "my_function({foo => bar})".should parse_with { |fun|
            fun.is_a?(Puppet::Parser::AST::Function) &&
            fun.arguments[0].evaluate(stub 'scope') == {'foo' => 'bar'}
          }
        end
      end

      describe "collections" do
        it "should find resources according to an expression" do
          %q{ File <| mode == 0700 + 0050 + 0050 |> }.should parse_with { |coll|
            coll.is_a?(Puppet::Parser::AST::Collection) &&
              coll.query.evaluate(stub 'scope').first == ["mode", "==", 0700 + 0050 + 0050]
          }
        end
      end
    end
  end

  describe 'using classic parser' do
    before :each do
      Puppet[:parser] = 'current'
    end
    it_behaves_like 'a puppet parser'
  end

  describe 'using future parser' do
    before :each do
      Puppet[:parser] = 'future'
    end
    it_behaves_like 'a puppet parser'

    context 'more detailed errors should be generated' do
      before :each do
        Puppet[:parser] = 'future'
        @resource_type_collection = Puppet::Resource::TypeCollection.new("env")
        @parser = Puppet::Parser::ParserFactory.parser("development")
      end

      it 'should flag illegal type references' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        1+1 { "title": }
        SOURCE
        # This error message is currently produced by the parser, and is not as detailed as desired
        # It references position 16 at the closing '}'
        expect { @parser.parse(source) }.to raise_error(/Expression is not valid as a resource.*line 1:16/)
      end

      it 'should flag illegal type references and get position correct' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        1+1 { "title":
          }
        SOURCE
        # This error message is currently produced by the parser, and is not as detailed as desired
        # It references position 16 at the closing '}'
        expect { @parser.parse(source) }.to raise_error(/Expression is not valid as a resource.*line 2:3/)
      end

      it 'should flag illegal use of non r-value producing if' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        $a = if true {
          false
        }
        SOURCE
        expect { @parser.parse(source) }.to raise_error(/An 'if' statement does not produce a value at line 1:6/)
      end

      it 'should flag illegal use of non r-value producing case' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        $a = case true {
          false :{ }
        }
        SOURCE
        expect { @parser.parse(source) }.to raise_error(/A 'case' statement does not produce a value at line 1:6/)
      end

      it 'should flag illegal use of non r-value producing <| |>' do
        expect { @parser.parse("$a = file <| |>") }.to raise_error(/A Virtual Query does not produce a value at line 1:6/)
      end

      it 'should flag illegal use of non r-value producing <<| |>>' do
        expect { @parser.parse("$a = file <<| |>>") }.to raise_error(/An Exported Query does not produce a value at line 1:6/)
      end

      it 'should flag illegal use of non r-value producing define' do
        Puppet.expects(:err).with("Invalid use of expression. A 'define' expression does not produce a value at line 1:6")
        Puppet.expects(:err).with("Classes, definitions, and nodes may only appear at toplevel or inside other classes at line 1:6")
        expect { @parser.parse("$a = define foo { }") }.to raise_error(/2 errors/)
      end

      it 'should flag illegal use of non r-value producing class' do
        Puppet.expects(:err).with("Invalid use of expression. A Host Class Definition does not produce a value at line 1:6")
        Puppet.expects(:err).with("Classes, definitions, and nodes may only appear at toplevel or inside other classes at line 1:6")
        expect { @parser.parse("$a = class foo { }") }.to raise_error(/2 errors/)
      end

      it 'unclosed quote should be flagged for start position of string' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        $a = "xx
        yyy
        SOURCE
        expect { @parser.parse(source) }.to raise_error(/Unclosed quote after '"' followed by 'xx\\nyy\.\.\.' at line 1:6/)
      end

      it 'can produce multiple errors and raise a summary exception' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        $a = node x { }
        SOURCE
        Puppet.expects(:err).with("Invalid use of expression. A Node Definition does not produce a value at line 1:6")
        Puppet.expects(:err).with("Classes, definitions, and nodes may only appear at toplevel or inside other classes at line 1:6")
        expect { @parser.parse(source) }.to raise_error(/2 errors/)
      end

      it 'can produce detailed error for a bad hostname' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        node 'macbook+owned+by+name' { }
        SOURCE
        expect { @parser.parse(source) }.to raise_error(/The hostname 'macbook\+owned\+by\+name' contains illegal characters.*at line 1:6/)
      end

      it 'can produce detailed error for a hostname with interpolation' do
        source = <<-SOURCE.gsub(/^ {8}/,'')
        $name = 'fred'
        node "macbook-owned-by$name" { }
        SOURCE
        expect { @parser.parse(source) }.to raise_error(/An interpolated expression is not allowed in a hostname of a node at line 2:24/)
      end
    end
  end
end
