#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'

# This is a special matcher to match easily lexer output
RSpec::Matchers.define :be_like do |*expected|
  match do |actual|
    diffable
    expected.zip(actual).all? { |e,a| !e or a[0] == e or (e.is_a? Array and a[0] == e[0] and (a[1] == e[1] or (a[1].is_a?(Hash) and a[1][:value] == e[1]))) }
  end
end
__ = nil

module EgrammarLexerSpec
  def self.tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer.new
    lexer.string = s
    lexer.fullscan[0..-2]
  end
end

describe Puppet::Pops::Parser::Lexer do
  include EgrammarLexerSpec

  describe "when reading strings" do
    before { @lexer = Puppet::Pops::Parser::Lexer.new }

    it "should increment the line count for every carriage return in the string" do
      @lexer.string = "'this\nis\natest'"
      @lexer.fullscan[0..-2]

      line = @lexer.line
      line.should == 3
    end

    it "should not increment the line count for escapes in the string" do
      @lexer.string = "'this\\nis\\natest'"
      @lexer.fullscan[0..-2]

      @lexer.line.should == 1
    end

    it "should not think the terminator is escaped, when preceeded by an even number of backslashes" do
      @lexer.string = "'here\nis\nthe\nstring\\\\'with\nextra\njunk"
      @lexer.fullscan[0..-2]

      @lexer.line.should == 6
    end

    {
      'r'  => "\r",
      'n'  => "\n",
      't'  => "\t",
      's'  => " "
    }.each do |esc, expected_result|
      it "should recognize \\#{esc} sequence" do
        @lexer.string = "\\#{esc}'"
        @lexer.slurpstring("'")[0].should == expected_result
      end
    end
  end
end

describe Puppet::Pops::Parser::Lexer::Token, "when initializing" do
  it "should create a regex if the first argument is a string" do
    Puppet::Pops::Parser::Lexer::Token.new("something", :NAME).regex.should == %r{something}
  end

  it "should set the string if the first argument is one" do
    Puppet::Pops::Parser::Lexer::Token.new("something", :NAME).string.should == "something"
  end

  it "should set the regex if the first argument is one" do
    Puppet::Pops::Parser::Lexer::Token.new(%r{something}, :NAME).regex.should == %r{something}
  end
end

describe Puppet::Pops::Parser::Lexer::TokenList do
  before do
    @list = Puppet::Pops::Parser::Lexer::TokenList.new
  end

  it "should have a method for retrieving tokens by the name" do
    token = @list.add_token :name, "whatever"
    @list[:name].should equal(token)
  end

  it "should have a method for retrieving string tokens by the string" do
    token = @list.add_token :name, "whatever"
    @list.lookup("whatever").should equal(token)
  end

  it "should add tokens to the list when directed" do
    token = @list.add_token :name, "whatever"
    @list[:name].should equal(token)
  end

  it "should have a method for adding multiple tokens at once" do
    @list.add_tokens "whatever" => :name, "foo" => :bar
    @list[:name].should_not be_nil
    @list[:bar].should_not be_nil
  end

  it "should fail to add tokens sharing a name with an existing token" do
    @list.add_token :name, "whatever"
    expect { @list.add_token :name, "whatever" }.to raise_error(ArgumentError)
  end

  it "should set provided options on tokens being added" do
    token = @list.add_token :name, "whatever", :skip_text => true
    token.skip_text.should == true
  end

  it "should define any provided blocks as a :convert method" do
    token = @list.add_token(:name, "whatever")  do "foo" end
    token.convert.should == "foo"
  end

  it "should store all string tokens in the :string_tokens list" do
    one = @list.add_token(:name, "1")
    @list.string_tokens.should be_include(one)
  end

  it "should store all regex tokens in the :regex_tokens list" do
    one = @list.add_token(:name, %r{one})
    @list.regex_tokens.should be_include(one)
  end

  it "should not store string tokens in the :regex_tokens list" do
    one = @list.add_token(:name, "1")
    @list.regex_tokens.should_not be_include(one)
  end

  it "should not store regex tokens in the :string_tokens list" do
    one = @list.add_token(:name, %r{one})
    @list.string_tokens.should_not be_include(one)
  end

  it "should sort the string tokens inversely by length when asked" do
    one = @list.add_token(:name, "1")
    two = @list.add_token(:other, "12")
    @list.sort_tokens
    @list.string_tokens.should == [two, one]
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS do
  before do
    @lexer = Puppet::Pops::Parser::Lexer.new
  end

  {
    :LBRACK => '[',
    :RBRACK => ']',
#    :LBRACE => '{',
#    :RBRACE => '}',
    :LPAREN => '(',
    :RPAREN => ')',
    :EQUALS => '=',
    :ISEQUAL => '==',
    :GREATEREQUAL => '>=',
    :GREATERTHAN => '>',
    :LESSTHAN => '<',
    :LESSEQUAL => '<=',
    :NOTEQUAL => '!=',
    :NOT => '!',
    :COMMA => ',',
    :DOT => '.',
    :COLON => ':',
    :AT => '@',
    :LLCOLLECT => '<<|',
    :RRCOLLECT => '|>>',
    :LCOLLECT => '<|',
    :RCOLLECT => '|>',
    :SEMIC => ';',
    :QMARK => '?',
    :BACKSLASH => '\\',
    :FARROW => '=>',
    :PARROW => '+>',
    :APPENDS => '+=',
    :PLUS => '+',
    :MINUS => '-',
    :DIV => '/',
    :TIMES => '*',
    :LSHIFT => '<<',
    :RSHIFT => '>>',
    :MATCH => '=~',
    :NOMATCH => '!~',
    :IN_EDGE => '->',
    :OUT_EDGE => '<-',
    :IN_EDGE_SUB => '~>',
    :OUT_EDGE_SUB => '<~',
    :PIPE => '|',
  }.each do |name, string|
    it "should have a token named #{name.to_s}" do
      Puppet::Pops::Parser::Lexer::TOKENS[name].should_not be_nil
    end

    it "should match '#{string}' for the token #{name.to_s}" do
      Puppet::Pops::Parser::Lexer::TOKENS[name].string.should == string
    end
  end

  {
    "case" => :CASE,
    "class" => :CLASS,
    "default" => :DEFAULT,
    "define" => :DEFINE,
#    "import" => :IMPORT, # done as a function in egrammar
    "if" => :IF,
    "elsif" => :ELSIF,
    "else" => :ELSE,
    "inherits" => :INHERITS,
    "node" => :NODE,
    "and"  => :AND,
    "or"   => :OR,
    "undef"   => :UNDEF,
    "false" => :FALSE,
    "true" => :TRUE,
    "in" => :IN,
    "unless" => :UNLESS,
  }.each do |string, name|
    it "should have a keyword named #{name.to_s}" do
      Puppet::Pops::Parser::Lexer::KEYWORDS[name].should_not be_nil
    end

    it "should have the keyword for #{name.to_s} set to #{string}" do
      Puppet::Pops::Parser::Lexer::KEYWORDS[name].string.should == string
    end
  end

  # These tokens' strings don't matter, just that the tokens exist.
  [:STRING, :DQPRE, :DQMID, :DQPOST, :BOOLEAN, :NAME, :NUMBER, :COMMENT, :MLCOMMENT,
    :LBRACE, :RBRACE,
    :RETURN, :SQUOTE, :DQUOTE, :VARIABLE].each do |name|
    it "should have a token named #{name.to_s}" do
      Puppet::Pops::Parser::Lexer::TOKENS[name].should_not be_nil
    end
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:CLASSREF] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:CLASSREF] }

  it "should match against single upper-case alpha-numeric terms" do
    @token.regex.should =~ "One"
  end

  it "should match against upper-case alpha-numeric terms separated by double colons" do
    @token.regex.should =~ "One::Two"
  end

  it "should match against many upper-case alpha-numeric terms separated by double colons" do
    @token.regex.should =~ "One::Two::Three::Four::Five"
  end

  it "should match against upper-case alpha-numeric terms prefixed by double colons" do
    @token.regex.should =~ "::One"
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:NAME] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:NAME] }

  it "should match against lower-case alpha-numeric terms" do
    @token.regex.should =~ "one-two"
  end

  it "should return itself and the value if the matched term is not a keyword" do
    Puppet::Pops::Parser::Lexer::KEYWORDS.expects(:lookup).returns(nil)
    @token.convert(stub("lexer"), "myval").should == [Puppet::Pops::Parser::Lexer::TOKENS[:NAME], "myval"]
  end

  it "should return the keyword token and the value if the matched term is a keyword" do
    keyword = stub 'keyword', :name => :testing
    Puppet::Pops::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
    @token.convert(stub("lexer"), "myval").should == [keyword, "myval"]
  end

  it "should return the BOOLEAN token and 'true' if the matched term is the string 'true'" do
    keyword = stub 'keyword', :name => :TRUE
    Puppet::Pops::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
    @token.convert(stub('lexer'), "true").should == [Puppet::Pops::Parser::Lexer::TOKENS[:BOOLEAN], true]
  end

  it "should return the BOOLEAN token and 'false' if the matched term is the string 'false'" do
    keyword = stub 'keyword', :name => :FALSE
    Puppet::Pops::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
    @token.convert(stub('lexer'), "false").should == [Puppet::Pops::Parser::Lexer::TOKENS[:BOOLEAN], false]
  end

  it "should match against lower-case alpha-numeric terms separated by double colons" do
    @token.regex.should =~ "one::two"
  end

  it "should match against many lower-case alpha-numeric terms separated by double colons" do
    @token.regex.should =~ "one::two::three::four::five"
  end

  it "should match against lower-case alpha-numeric terms prefixed by double colons" do
    @token.regex.should =~ "::one"
  end

  it "should match against nested terms starting with numbers" do
    @token.regex.should =~ "::1one::2two::3three"
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:NUMBER] do
  before do
    @token = Puppet::Pops::Parser::Lexer::TOKENS[:NUMBER]
    @regex = @token.regex
  end

  it "should match against numeric terms" do
    @regex.should =~ "2982383139"
  end

  it "should match against float terms" do
    @regex.should =~ "29823.235"
  end

  it "should match against hexadecimal terms" do
    @regex.should =~ "0xBEEF0023"
  end

  it "should match against float with exponent terms" do
    @regex.should =~ "10e23"
  end

  it "should match against float terms with negative exponents" do
    @regex.should =~ "10e-23"
  end

  it "should match against float terms with fractional parts and exponent" do
    @regex.should =~ "1.234e23"
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:COMMENT] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:COMMENT] }

  it "should match against lines starting with '#'" do
    @token.regex.should =~ "# this is a comment"
  end

  it "should be marked to get skipped" do
    @token.skip?.should be_true
  end

  it "'s block should return the comment without the #" do
    @token.convert(@lexer,"# this is a comment")[1].should == "this is a comment"
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:MLCOMMENT] do
  before do
    @token = Puppet::Pops::Parser::Lexer::TOKENS[:MLCOMMENT]
    @lexer = stub 'lexer', :line => 0
  end

  it "should match against lines enclosed with '/*' and '*/'" do
    @token.regex.should =~ "/* this is a comment */"
  end

  it "should match multiple lines enclosed with '/*' and '*/'" do
    @token.regex.should =~ """/*
      this is a comment
      */"""
  end

#  # TODO: REWRITE THIS TEST TO NOT BE BASED ON INTERNALS
#  it "should increase the lexer current line number by the amount of lines spanned by the comment" do
#    @lexer.expects(:line=).with(2)
#    @token.convert(@lexer, "1\n2\n3")
#  end

  it "should not greedily match comments" do
    match = @token.regex.match("/* first */ word /* second */")
    match[1].should == " first "
  end

  it "'s block should return the comment without the comment marks" do
    @lexer.stubs(:line=).with(0)

    @token.convert(@lexer,"/* this is a comment */")[1].should == "this is a comment"
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:RETURN] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:RETURN] }

  it "should match against carriage returns" do
    @token.regex.should =~ "\n"
  end

  it "should be marked to initiate text skipping" do
    @token.skip_text.should be_true
  end
end

shared_examples_for "handling `-` in standard variable names for egrammar" do |prefix|
  # Watch out - a regex might match a *prefix* on these, not just the whole
  # word, so make sure you don't have false positive or negative results based
  # on that.
  legal   = %w{f foo f::b foo::b f::bar foo::bar 3 foo3 3foo}
  illegal = %w{f- f-o -f f::-o f::o- f::o-o}

  ["", "::"].each do |global_scope|
    legal.each do |name|
      var = prefix + global_scope + name
      it "should accept #{var.inspect} as a valid variable name" do
        (subject.regex.match(var) || [])[0].should == var
      end
    end

    illegal.each do |name|
      var = prefix + global_scope + name
      it "when `variable_with_dash` is disabled it should NOT accept #{var.inspect} as a valid variable name" do
        Puppet[:allow_variables_with_dashes] = false
        (subject.regex.match(var) || [])[0].should_not == var
      end

      it "when `variable_with_dash` is enabled it should NOT accept #{var.inspect} as a valid variable name" do
        Puppet[:allow_variables_with_dashes] = true
        (subject.regex.match(var) || [])[0].should_not == var
      end
    end
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:DOLLAR_VAR] do
  its(:skip_text) { should be_false }

  it_should_behave_like "handling `-` in standard variable names for egrammar", '$'
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:VARIABLE] do
  its(:skip_text) { should be_false }

  it_should_behave_like "handling `-` in standard variable names for egrammar", ''
end

describe "the horrible deprecation / compatibility variables with dashes" do
  ENamesWithDashes = %w{f- f-o -f f::-o f::o- f::o-o}

  { Puppet::Pops::Parser::Lexer::TOKENS[:DOLLAR_VAR_WITH_DASH] => '$',
    Puppet::Pops::Parser::Lexer::TOKENS[:VARIABLE_WITH_DASH]   => ''
  }.each do |token, prefix|
    describe token do
      its(:skip_text) { should be_false }

      context "when compatibly is disabled" do
        before :each do Puppet[:allow_variables_with_dashes] = false end
        Puppet::Pops::Parser::Lexer::TOKENS.each do |name, value|
          it "should be unacceptable after #{name}" do
            token.acceptable?(:after => name).should be_false
          end
        end

        # Yes, this should still *match*, just not be acceptable.
        ENamesWithDashes.each do |name|
          ["", "::"].each do |global_scope|
            var = prefix + global_scope + name
            it "should match #{var.inspect}" do
              subject.regex.match(var).to_a.should == [var]
            end
          end
        end
      end

      context "when compatibility is enabled" do
        before :each do Puppet[:allow_variables_with_dashes] = true end

        it "should be acceptable after DQPRE" do
          token.acceptable?(:after => :DQPRE).should be_true
        end

        ENamesWithDashes.each do |name|
          ["", "::"].each do |global_scope|
            var = prefix + global_scope + name
            it "should match #{var.inspect}" do
              subject.regex.match(var).to_a.should == [var]
            end
          end
        end
      end
    end
  end

  context "deprecation warnings" do
    before :each do Puppet[:allow_variables_with_dashes] = true end

    it "should match a top level variable" do
      Puppet.expects(:deprecation_warning).once

      EgrammarLexerSpec.tokens_scanned_from('$foo-bar').should == [
        [:VARIABLE, {:value=>"foo-bar", :line=>1, :pos=>1, :offset=>0, :length=>8}]
      ]
    end

    it "does not warn about a variable without a dash" do
      Puppet.expects(:deprecation_warning).never

      EgrammarLexerSpec.tokens_scanned_from('$c').should == [
        [:VARIABLE, {:value=>"c", :line=>1, :pos=>1, :offset=>0, :length=>2}]
      ]
    end

    it "does not warn about referencing a class name that contains a dash" do
      Puppet.expects(:deprecation_warning).never

      EgrammarLexerSpec.tokens_scanned_from('foo-bar').should == [
        [:NAME, {:value=>"foo-bar", :line=>1, :pos=>1, :offset=>0, :length=>7}]
      ]
    end

    it "warns about reference to variable" do
      Puppet.expects(:deprecation_warning).once

      EgrammarLexerSpec.tokens_scanned_from('$::foo-bar::baz-quux').should == [
        [:VARIABLE, {:value=>"::foo-bar::baz-quux", :line=>1, :pos=>1, :offset=>0, :length=>20}]
      ]
    end

    it "warns about reference to variable interpolated in a string" do
      Puppet.expects(:deprecation_warning).once

      EgrammarLexerSpec.tokens_scanned_from('"$::foo-bar::baz-quux"').should == [
        [:DQPRE,    {:value=>"", :line=>1, :pos=>1, :offset=>0, :length=>2}],  # length since preamble includes start and terminator
        [:VARIABLE, {:value=>"::foo-bar::baz-quux", :line=>1, :pos=>3, :offset=>2, :length=>19}],
        [:DQPOST,   {:value=>"", :line=>1, :pos=>22, :offset=>21, :length=>1}],
      ]
    end

    it "warns about reference to variable interpolated in a string as an expression" do
      Puppet.expects(:deprecation_warning).once

      EgrammarLexerSpec.tokens_scanned_from('"${::foo-bar::baz-quux}"').should == [
        [:DQPRE,    {:value=>"", :line=>1, :pos=>1, :offset=>0, :length=>3}],
        [:VARIABLE, {:value=>"::foo-bar::baz-quux", :line=>1, :pos=>4, :offset=>3, :length=>19}],
        [:DQPOST,   {:value=>"", :line=>1, :pos=>23, :offset=>22, :length=>2}],
      ]
    end
  end
end


describe Puppet::Pops::Parser::Lexer,"when lexing strings" do
  {
    %q{'single quoted string')}                                     => [[:STRING,'single quoted string']],
    %q{"double quoted string"}                                      => [[:STRING,'double quoted string']],
    %q{'single quoted string with an escaped "\\'"'}                => [[:STRING,'single quoted string with an escaped "\'"']],
    %q{'single quoted string with an escaped "\$"'}                 => [[:STRING,'single quoted string with an escaped "\$"']],
    %q{'single quoted string with an escaped "\."'}                 => [[:STRING,'single quoted string with an escaped "\."']],
    %q{'single quoted string with an escaped "\r\n"'}               => [[:STRING,'single quoted string with an escaped "\r\n"']],
    %q{'single quoted string with an escaped "\n"'}                 => [[:STRING,'single quoted string with an escaped "\n"']],
    %q{'single quoted string with an escaped "\\\\"'}               => [[:STRING,'single quoted string with an escaped "\\\\"']],
    %q{"string with an escaped '\\"'"}                              => [[:STRING,"string with an escaped '\"'"]],
    %q{"string with an escaped '\\$'"}                              => [[:STRING,"string with an escaped '$'"]],
    %Q{"string with a line ending with a backslash: \\\nfoo"}       => [[:STRING,"string with a line ending with a backslash: foo"]],
    %q{"string with $v (but no braces)"}                            => [[:DQPRE,"string with "],[:VARIABLE,'v'],[:DQPOST,' (but no braces)']],
    %q["string with ${v} in braces"]                                => [[:DQPRE,"string with "],[:VARIABLE,'v'],[:DQPOST,' in braces']],
    %q["string with ${qualified::var} in braces"]                   => [[:DQPRE,"string with "],[:VARIABLE,'qualified::var'],[:DQPOST,' in braces']],
    %q{"string with $v and $v (but no braces)"}                     => [[:DQPRE,"string with "],[:VARIABLE,"v"],[:DQMID," and "],[:VARIABLE,"v"],[:DQPOST," (but no braces)"]],
    %q["string with ${v} and ${v} in braces"]                       => [[:DQPRE,"string with "],[:VARIABLE,"v"],[:DQMID," and "],[:VARIABLE,"v"],[:DQPOST," in braces"]],
    %q["string with ${'a nested single quoted string'} inside it."] => [[:DQPRE,"string with "],[:STRING,'a nested single quoted string'],[:DQPOST,' inside it.']],
    %q["string with ${['an array ',$v2]} in it."]                   => [[:DQPRE,"string with "],:LBRACK,[:STRING,"an array "],:COMMA,[:VARIABLE,"v2"],:RBRACK,[:DQPOST," in it."]],
    %q{a simple "scanner" test}                                     => [[:NAME,"a"],[:NAME,"simple"], [:STRING,"scanner"],[:NAME,"test"]],
    %q{a simple 'single quote scanner' test}                        => [[:NAME,"a"],[:NAME,"simple"], [:STRING,"single quote scanner"],[:NAME,"test"]],
    %q{a harder 'a $b \c"'}                                         => [[:NAME,"a"],[:NAME,"harder"], [:STRING,'a $b \c"']],
    %q{a harder "scanner test"}                                     => [[:NAME,"a"],[:NAME,"harder"], [:STRING,"scanner test"]],
    %q{a hardest "scanner \"test\""}                                => [[:NAME,"a"],[:NAME,"hardest"],[:STRING,'scanner "test"']],
    %Q{a hardestest "scanner \\"test\\"\n"}                         => [[:NAME,"a"],[:NAME,"hardestest"],[:STRING,%Q{scanner "test"\n}]],
    %q{function("call")}                                            => [[:NAME,"function"],[:LPAREN,"("],[:STRING,'call'],[:RPAREN,")"]],
    %q["string with ${(3+5)/4} nested math."]                       => [[:DQPRE,"string with "],:LPAREN,[:NAME,"3"],:PLUS,[:NAME,"5"],:RPAREN,:DIV,[:NAME,"4"],[:DQPOST," nested math."]],
    %q["$$$$"]                                                      => [[:STRING,"$$$$"]],
    %q["$variable"]                                                 => [[:DQPRE,""],[:VARIABLE,"variable"],[:DQPOST,""]],
    %q["$var$other"]                                                => [[:DQPRE,""],[:VARIABLE,"var"],[:DQMID,""],[:VARIABLE,"other"],[:DQPOST,""]],
    %q["foo$bar$"]                                                  => [[:DQPRE,"foo"],[:VARIABLE,"bar"],[:DQPOST,"$"]],
    %q["foo$$bar"]                                                  => [[:DQPRE,"foo$"],[:VARIABLE,"bar"],[:DQPOST,""]],
    %q[""]                                                          => [[:STRING,""]],
    %q["123 456 789 0"]                                             => [[:STRING,"123 456 789 0"]],
    %q["${123} 456 $0"]                                             => [[:DQPRE,""],[:VARIABLE,"123"],[:DQMID," 456 "],[:VARIABLE,"0"],[:DQPOST,""]],
    %q["$foo::::bar"]                                               => [[:DQPRE,""],[:VARIABLE,"foo"],[:DQPOST,"::::bar"]],
    # Keyword variables
    %q["$true"]                                                     => [[:DQPRE,""],[:VARIABLE, "true"],[:DQPOST,""]],
    %q["$false"]                                                    => [[:DQPRE,""],[:VARIABLE, "false"],[:DQPOST,""]],
    %q["$if"]                                                       => [[:DQPRE,""],[:VARIABLE, "if"],[:DQPOST,""]],
    %q["$case"]                                                     => [[:DQPRE,""],[:VARIABLE, "case"],[:DQPOST,""]],
    %q["$unless"]                                                   => [[:DQPRE,""],[:VARIABLE, "unless"],[:DQPOST,""]],
    %q["$undef"]                                                    => [[:DQPRE,""],[:VARIABLE, "undef"],[:DQPOST,""]],
    # Expressions
    %q["${true}"]                                                   => [[:DQPRE,""],[:BOOLEAN, true],[:DQPOST,""]],
    %q["${false}"]                                                  => [[:DQPRE,""],[:BOOLEAN, false],[:DQPOST,""]],
    %q["${undef}"]                                                  => [[:DQPRE,""],:UNDEF,[:DQPOST,""]],
    %q["${if true {false}}"]                                        => [[:DQPRE,""],:IF,[:BOOLEAN, true], :LBRACE, [:BOOLEAN, false], :RBRACE, [:DQPOST,""]],
    %q["${unless true {false}}"]                                    => [[:DQPRE,""],:UNLESS,[:BOOLEAN, true], :LBRACE, [:BOOLEAN, false], :RBRACE, [:DQPOST,""]],
    %q["${case true {true:{false}}}"] => [
      [:DQPRE,""],:CASE,[:BOOLEAN, true], :LBRACE, [:BOOLEAN, true], :COLON, :LBRACE, [:BOOLEAN, false],
        :RBRACE, :RBRACE, [:DQPOST,""]],
    %q[{ "${a}" => 1 }] => [ :LBRACE, [:DQPRE,""], [:VARIABLE,"a"], [:DQPOST,""], :FARROW, [:NAME,"1"], :RBRACE ],
  }.each { |src,expected_result|
    it "should handle #{src} correctly" do
      EgrammarLexerSpec.tokens_scanned_from(src).should be_like(*expected_result)
    end
  }
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:DOLLAR_VAR] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:DOLLAR_VAR] }

  it "should match against alpha words prefixed with '$'" do
    @token.regex.should =~ '$this_var'
  end

  it "should return the VARIABLE token and the variable name stripped of the '$'" do
    @token.convert(stub("lexer"), "$myval").should == [Puppet::Pops::Parser::Lexer::TOKENS[:VARIABLE], "myval"]
  end
end

describe Puppet::Pops::Parser::Lexer::TOKENS[:REGEX] do
  before { @token = Puppet::Pops::Parser::Lexer::TOKENS[:REGEX] }

  it "should match against any expression enclosed in //" do
    @token.regex.should =~ '/this is a regex/'
  end

  it 'should not match if there is \n in the regex' do
    @token.regex.should_not =~ "/this is \n a regex/"
  end

  describe "when scanning" do
    it "should not consider escaped slashes to be the end of a regex" do
      EgrammarLexerSpec.tokens_scanned_from("$x =~ /this \\/ foo/").should be_like(__,__,[:REGEX,%r{this / foo}])
    end

    it "should not lex chained division as a regex" do
      EgrammarLexerSpec.tokens_scanned_from("$x = $a/$b/$c").collect { |name, data| name }.should_not be_include( :REGEX )
    end

    it "should accept a regular expression after NODE" do
      EgrammarLexerSpec.tokens_scanned_from("node /www.*\.mysite\.org/").should be_like(__,[:REGEX,Regexp.new("www.*\.mysite\.org")])
    end

    it "should accept regular expressions in a CASE" do
      s = %q{case $variable {
        "something": {$othervar = 4096 / 2}
        /regex/: {notice("this notably sucks")}
        }
      }
      EgrammarLexerSpec.tokens_scanned_from(s).should be_like(
        :CASE,:VARIABLE,:LBRACE,:STRING,:COLON,:LBRACE,:VARIABLE,:EQUALS,:NAME,:DIV,:NAME,:RBRACE,[:REGEX,/regex/],:COLON,:LBRACE,:NAME,:LPAREN,:STRING,:RPAREN,:RBRACE,:RBRACE
      )
    end
  end

  it "should return the REGEX token and a Regexp" do
    @token.convert(stub("lexer"), "/myregex/").should == [Puppet::Pops::Parser::Lexer::TOKENS[:REGEX], Regexp.new(/myregex/)]
  end
end

describe Puppet::Pops::Parser::Lexer, "when lexing comments" do
  before { @lexer = Puppet::Pops::Parser::Lexer.new }

  it "should skip whitespace before lexing the next token after a non-token" do
    EgrammarLexerSpec.tokens_scanned_from("/* 1\n\n */ \ntest").should be_like([:NAME, "test"])
  end
end

# FIXME: We need to rewrite all of these tests, but I just don't want to take the time right now.
describe "Puppet::Pops::Parser::Lexer in the old tests" do
  before { @lexer = Puppet::Pops::Parser::Lexer.new }

  it "should do simple lexing" do
    {
      %q{\\}                      => [[:BACKSLASH,"\\"]],
      %q{simplest scanner test}   => [[:NAME,"simplest"],[:NAME,"scanner"],[:NAME,"test"]],
      %Q{returned scanner test\n} => [[:NAME,"returned"],[:NAME,"scanner"],[:NAME,"test"]]
    }.each { |source,expected|
      EgrammarLexerSpec.tokens_scanned_from(source).should be_like(*expected)
    }
  end

  it "should fail usefully" do
    expect { EgrammarLexerSpec.tokens_scanned_from('^') }.to raise_error(RuntimeError)
  end

  it "should fail if the string is not set" do
    expect { @lexer.fullscan }.to raise_error(Puppet::LexError)
  end

  it "should correctly identify keywords" do
    EgrammarLexerSpec.tokens_scanned_from("case").should be_like([:CASE, "case"])
  end

  it "should correctly parse class references" do
    %w{Many Different Words A Word}.each { |t| EgrammarLexerSpec.tokens_scanned_from(t).should be_like([:CLASSREF,t])}
  end

  # #774
  it "should correctly parse namespaced class refernces token" do
    %w{Foo ::Foo Foo::Bar ::Foo::Bar}.each { |t| EgrammarLexerSpec.tokens_scanned_from(t).should be_like([:CLASSREF, t]) }
  end

  it "should correctly parse names" do
    %w{this is a bunch of names}.each { |t| EgrammarLexerSpec.tokens_scanned_from(t).should be_like([:NAME,t]) }
  end

  it "should correctly parse names with numerals" do
    %w{1name name1 11names names11}.each { |t| EgrammarLexerSpec.tokens_scanned_from(t).should be_like([:NAME,t]) }
  end

  it "should correctly parse empty strings" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = ""') }.to_not raise_error
  end

  it "should correctly parse virtual resources" do
    EgrammarLexerSpec.tokens_scanned_from("@type {").should be_like([:AT, "@"], [:NAME, "type"], [:LBRACE, "{"])
  end

  it "should correctly deal with namespaces" do
    @lexer.string = %{class myclass}
    @lexer.fullscan
    @lexer.namespace.should == "myclass"

    @lexer.namepop
    @lexer.namespace.should == ""

    @lexer.string = "class base { class sub { class more"
    @lexer.fullscan
    @lexer.namespace.should == "base::sub::more"

    @lexer.namepop
    @lexer.namespace.should == "base::sub"
  end

  it "should not put class instantiation on the namespace" do
    @lexer.string = "class base { class sub { class { mode"
    @lexer.fullscan
    @lexer.namespace.should == "base::sub"
  end

  it "should correctly handle fully qualified names" do
    @lexer.string = "class base { class sub::more {"
    @lexer.fullscan
    @lexer.namespace.should == "base::sub::more"

    @lexer.namepop
    @lexer.namespace.should == "base"
  end

  it "should correctly lex variables" do
    ["$variable", "$::variable", "$qualified::variable", "$further::qualified::variable"].each do |string|
      EgrammarLexerSpec.tokens_scanned_from(string).should be_like([:VARIABLE,string.sub(/^\$/,'')])
    end
  end

  it "should end variables at `-`" do
    EgrammarLexerSpec.tokens_scanned_from('$hyphenated-variable').
      should be_like([:VARIABLE, "hyphenated"], [:MINUS, '-'], [:NAME, 'variable'])
  end

  it "should not include whitespace in a variable" do
    EgrammarLexerSpec.tokens_scanned_from("$foo bar").should_not be_like([:VARIABLE, "foo bar"])
  end
  it "should not include excess colons in a variable" do
    EgrammarLexerSpec.tokens_scanned_from("$foo::::bar").should_not be_like([:VARIABLE, "foo::::bar"])
  end
end

describe "Puppet::Pops::Parser::Lexer in the old tests when lexing example files" do
  my_fixtures('*.pp') do |file|
    it "should correctly lex #{file}" do
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      expect { lexer.fullscan }.to_not raise_error
    end
  end
end

describe "when trying to lex a non-existent file" do
  include PuppetSpec::Files

  it "should return an empty list of tokens" do
    lexer = Puppet::Pops::Parser::Lexer.new
    lexer.file = nofile = tmpfile('lexer')
    File.exists?(nofile).should == false

    lexer.fullscan.should == [[false,false]]
  end
end

describe "when string quotes are not closed" do
  it "should report with message including an \" opening quote" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = "') }.to raise_error(/after '"'/)
  end

  it "should report with message including an \' opening quote" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = \'') }.to raise_error(/after "'"/)
  end

  it "should report <eof> if immediately followed by eof" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = "') }.to raise_error(/followed by '<eof>'/)
  end

  it "should report max 5 chars following quote" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = "123456') }.to raise_error(/followed by '12345...'/)
  end

  it "should escape control chars" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = "12\n3456') }.to raise_error(/followed by '12\\n3...'/)
  end

  it "should resport position of opening quote" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = "123456') }.to raise_error(/at line 1:8/)
    expect { EgrammarLexerSpec.tokens_scanned_from('$var =  "123456') }.to raise_error(/at line 1:9/)
  end
end

describe "when lexing number, bad input should not go unpunished" do
  it "should slap bad octal as such" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = 0778') }.to raise_error(/Not a valid octal/)
  end

  it "should slap bad hex as such" do
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = 0xFG') }.to raise_error(/Not a valid hex/)
    expect { EgrammarLexerSpec.tokens_scanned_from('$var = 0xfg') }.to raise_error(/Not a valid hex/)
  end
  # Note, bad decimals are probably impossible to enter, as they are not recognized as complete numbers, instead,
  # the error will be something else, depending on what follows some initial digit.
  #
end

describe "when lexing interpolation detailed positioning should be correct" do
  it "should correctly position a string without interpolation" do
    EgrammarLexerSpec.tokens_scanned_from('"not interpolated"').should be_like(
      [:STRING, {:value=>"not interpolated", :line=>1, :offset=>0, :pos=>1, :length=>18}])
  end

  it "should correctly position a string with false start in interpolation" do
    EgrammarLexerSpec.tokens_scanned_from('"not $$$ rpolated"').should be_like(
      [:STRING, {:value=>"not $$$ rpolated", :line=>1, :offset=>0, :pos=>1, :length=>18}])
  end

  it "should correctly position pre-mid-end interpolation " do
    EgrammarLexerSpec.tokens_scanned_from('"pre $x mid $y end"').should be_like(
      [:DQPRE,    {:value=>"pre ", :line=>1, :offset=>0, :pos=>1, :length=>6}],
      [:VARIABLE, {:value=>"x", :line=>1, :offset=>6, :pos=>7, :length=>1}],
      [:DQMID,    {:value=>" mid ", :line=>1, :offset=>7, :pos=>8, :length=>6}],
      [:VARIABLE, {:value=>"y", :line=>1, :offset=>13, :pos=>14, :length=>1}],
      [:DQPOST,   {:value=>" end", :line=>1, :offset=>14, :pos=>15, :length=>5}]
    )
  end

  it "should correctly position pre-mid-end interpolation using ${} " do
    EgrammarLexerSpec.tokens_scanned_from('"pre ${x} mid ${y} end"').should be_like(
      [:DQPRE,    {:value=>"pre ", :line=>1, :offset=>0, :pos=>1, :length=>7}],
      [:VARIABLE, {:value=>"x", :line=>1, :offset=>7, :pos=>8, :length=>1}],
      [:DQMID,    {:value=>" mid ", :line=>1, :offset=>8, :pos=>9, :length=>8}],
      [:VARIABLE, {:value=>"y", :line=>1, :offset=>16, :pos=>17, :length=>1}],
      [:DQPOST,   {:value=>" end", :line=>1, :offset=>17, :pos=>18, :length=>6}]
    )
  end

  it "should correctly position pre-end interpolation using ${} with f call" do
    EgrammarLexerSpec.tokens_scanned_from('"pre ${x()} end"').should be_like(
      [:DQPRE,    {:value=>"pre ", :line=>1, :offset=>0, :pos=>1, :length=>7}],
      [:NAME,     {:value=>"x",    :line=>1, :offset=>7, :pos=>8, :length=>1}],
      [:LPAREN,   {:value=>"(",    :line=>1, :offset=>8, :pos=>9, :length=>1}],
      [:RPAREN,   {:value=>")",    :line=>1, :offset=>9, :pos=>10, :length=>1}],
      [:DQPOST,   {:value=>" end", :line=>1, :offset=>10, :pos=>11, :length=>6}]
    )
  end

  it "should correctly position pre-end interpolation using ${} with $x" do
    EgrammarLexerSpec.tokens_scanned_from('"pre ${$x} end"').should be_like(
      [:DQPRE,    {:value=>"pre ", :line=>1, :offset=>0, :pos=>1, :length=>7}],
      [:VARIABLE, {:value=>"x",    :line=>1, :offset=>7, :pos=>8, :length=>2}],
      [:DQPOST,   {:value=>" end", :line=>1, :offset=>9, :pos=>10, :length=>6}]
    )
  end

  it "should correctly position pre-end interpolation across lines" do
    EgrammarLexerSpec.tokens_scanned_from(%Q["pre ${\n$x} end"]).should be_like(
      [:DQPRE,    {:value=>"pre ", :line=>1, :offset=>0, :pos=>1, :length=>7}],
      [:VARIABLE, {:value=>"x",    :line=>2, :offset=>8, :pos=>1, :length=>2}],
      [:DQPOST,   {:value=>" end", :line=>2, :offset=>10, :pos=>3, :length=>6}]
    )
  end

  it "should correctly position interpolation across lines when strings have embedded newlines" do
    EgrammarLexerSpec.tokens_scanned_from(%Q["pre \n\n${$x}\n mid$y"]).should be_like(
      [:DQPRE,    {:value=>"pre \n\n", :line=>1, :offset=>0, :pos=>1, :length=>9}],
      [:VARIABLE, {:value=>"x",    :line=>3, :offset=>9, :pos=>3, :length=>2}],
      [:DQMID,   {:value=>"\n mid", :line=>3, :offset=>11, :pos=>5, :length=>7}],
      [:VARIABLE, {:value=>"y",    :line=>4, :offset=>18, :pos=>6, :length=>1}]
    )
  end
end
