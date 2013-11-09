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
    describe "when parsing comments before a statement" do
      it "should associate the documentation to the statement AST node" do
        if Puppet[:parser] == 'future'
          pending "egrammar does not yet process comments"
        end
        ast = @parser.parse("""
        # comment
        class test {
          $foo = {bar => 23}
          $bar = [23, 42]
          $x   = 'argument'
          # this comment should not be returned
          some_function('with', {a => 'hash'},
                        ['and', 1, 'array', $argument],
                      ) # not?
        }
        """)

        ast.code[0].should be_a(Puppet::Parser::AST::Hostclass)
        ast.code[0].name.should == 'test'
        ast.code[0].instantiate('')[0].doc.should == "comment\n"
      end

      { "an empty hash" => "{}",
        "a simple hash" => "{ 'key' => 'value' }",
        "a nested hash" => "{ 'first' => $x, 'second' => { a => 1, b => 2 } }"
      }.each_pair do |hash_desc, hash_expr|
        context "in the presence of #{hash_desc}" do
          { "a parameter default" => "class test($param = #{hash_expr}) { }",
            "a parameter value"   => "foo { 'bar': options => #{hash_expr} }",
            "an plusignment rvalue" => "Foo['bar'] { options +> #{hash_expr} }",
            "an assignment rvalue" => "$x = #{hash_expr}",
            "an inequality rvalue" => "if $x != #{hash_expr} { }",
            "an function argument in parenthesis"    => "flatten(#{hash_expr})",
            "a second argument" => "merge($x, #{hash_expr})",
          }.each_pair do |dsl_desc, dsl_expr|
            context "as #{dsl_desc}" do
              it "should associate the docstring to the container" do
                ast = @parser.parse("# comment\nclass container { #{dsl_expr} }\n")
                ast.code[0].instantiate('')[0].doc.should == "comment\n"
              end
            end
          end
          # Pending, these syntaxes are not yet supported in 3.x
          #
          # @todo Merge these into the test above after the migration to the new
          #   parser is complete.
          { "a selector alternative" => "$opt ? { { 'a' => 1 } => true, default => false }",
            "an argument without parenthesis" => "flatten { 'a' => 1 }",
          }.each_pair do |dsl_desc, dsl_expr|
            context "as #{dsl_desc}" do
              it "should associate the docstring to the container"
            end
          end
        end
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

end
