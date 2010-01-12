#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/lexer'

# This is a special matcher to match easily lexer output
Spec::Matchers.define :be_like do |ary|
    match do |result|
        r = true
        result.zip(ary) do |a,b|
            unless a[0] == b[0] and ((a[1].is_a?(Hash) and a[1][:value] == b[1]) or a[1] == b[1])
                r = false
                break
            end
        end
        r
    end
end

describe Puppet::Parser::Lexer do
    describe "when reading strings" do
        before { @lexer = Puppet::Parser::Lexer.new }
        it "should increment the line count for every carriage return in the string" do
            @lexer.line = 10
            @lexer.string = "this\nis\natest'"
            @lexer.slurpstring("'")

            @lexer.line.should == 12
        end

        it "should not increment the line count for escapes in the string" do
            @lexer.line = 10
            @lexer.string = "this\\nis\\natest'"
            @lexer.slurpstring("'")

            @lexer.line.should == 10
        end
    end
end

describe Puppet::Parser::Lexer::Token do
    before do
        @token = Puppet::Parser::Lexer::Token.new(%r{something}, :NAME)
    end

    [:regex, :name, :string, :skip, :incr_line, :skip_text, :accumulate].each do |param|
        it "should have a #{param.to_s} reader" do
            @token.should be_respond_to(param)
        end

        it "should have a #{param.to_s} writer" do
            @token.should be_respond_to(param.to_s + "=")
        end
    end
end

describe Puppet::Parser::Lexer::Token, "when initializing" do
    it "should create a regex if the first argument is a string" do
        Puppet::Parser::Lexer::Token.new("something", :NAME).regex.should == %r{something}
    end

    it "should set the string if the first argument is one" do
        Puppet::Parser::Lexer::Token.new("something", :NAME).string.should == "something"
    end

    it "should set the regex if the first argument is one" do
        Puppet::Parser::Lexer::Token.new(%r{something}, :NAME).regex.should == %r{something}
    end
end

describe Puppet::Parser::Lexer::TokenList do
    before do
        @list = Puppet::Parser::Lexer::TokenList.new
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
        lambda { @list.add_token :name, "whatever" }.should raise_error(ArgumentError)
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

describe Puppet::Parser::Lexer::TOKENS do
    before do
        @lexer = Puppet::Parser::Lexer.new()
    end

    {
        :LBRACK => '[',
        :RBRACK => ']',
        :LBRACE => '{',
        :RBRACE => '}',
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
    }.each do |name, string|
        it "should have a token named #{name.to_s}" do
            Puppet::Parser::Lexer::TOKENS[name].should_not be_nil
        end

        it "should match '#{string}' for the token #{name.to_s}" do
            Puppet::Parser::Lexer::TOKENS[name].string.should == string
        end
    end

    {
        "case" => :CASE,
        "class" => :CLASS,
        "default" => :DEFAULT,
        "define" => :DEFINE,
        "import" => :IMPORT,
        "if" => :IF,
        "elsif" => :ELSIF,
        "else" => :ELSE,
        "inherits" => :INHERITS,
        "node" => :NODE,
        "and"  => :AND,
        "or"   => :OR,
        "undef"   => :UNDEF,
        "false" => :FALSE,
        "true" => :TRUE
    }.each do |string, name|
        it "should have a keyword named #{name.to_s}" do
            Puppet::Parser::Lexer::KEYWORDS[name].should_not be_nil
        end

        it "should have the keyword for #{name.to_s} set to #{string}" do
            Puppet::Parser::Lexer::KEYWORDS[name].string.should == string
        end
    end

    # These tokens' strings don't matter, just that the tokens exist.
    [:DQTEXT, :SQTEXT, :BOOLEAN, :NAME, :NUMBER, :COMMENT, :MLCOMMENT, :RETURN, :SQUOTE, :DQUOTE, :VARIABLE].each do |name|
        it "should have a token named #{name.to_s}" do
            Puppet::Parser::Lexer::TOKENS[name].should_not be_nil
        end
    end
end

describe Puppet::Parser::Lexer::TOKENS[:CLASSNAME] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:CLASSNAME] }

    it "should match against lower-case alpha-numeric terms separated by double colons" do
        @token.regex.should =~ "one::two"
    end

    it "should match against many lower-case alpha-numeric terms separated by double colons" do
        @token.regex.should =~ "one::two::three::four::five"
    end

    it "should match against lower-case alpha-numeric terms prefixed by double colons" do
        @token.regex.should =~ "::one"
    end
end

describe Puppet::Parser::Lexer::TOKENS[:CLASSREF] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:CLASSREF] }

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

describe Puppet::Parser::Lexer::TOKENS[:NAME] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:NAME] }

    it "should match against lower-case alpha-numeric terms" do
        @token.regex.should =~ "one-two"
    end

    it "should return itself and the value if the matched term is not a keyword" do
        Puppet::Parser::Lexer::KEYWORDS.expects(:lookup).returns(nil)
        @token.convert(stub("lexer"), "myval").should == [Puppet::Parser::Lexer::TOKENS[:NAME], "myval"]
    end

    it "should return the keyword token and the value if the matched term is a keyword" do
        keyword = stub 'keyword', :name => :testing
        Puppet::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
        @token.convert(stub("lexer"), "myval").should == [keyword, "myval"]
    end

    it "should return the BOOLEAN token and 'true' if the matched term is the string 'true'" do
        keyword = stub 'keyword', :name => :TRUE
        Puppet::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
        @token.convert(stub('lexer'), "true").should == [Puppet::Parser::Lexer::TOKENS[:BOOLEAN], true]
    end

    it "should return the BOOLEAN token and 'false' if the matched term is the string 'false'" do
        keyword = stub 'keyword', :name => :FALSE
        Puppet::Parser::Lexer::KEYWORDS.expects(:lookup).returns(keyword)
        @token.convert(stub('lexer'), "false").should == [Puppet::Parser::Lexer::TOKENS[:BOOLEAN], false]
    end
end

describe Puppet::Parser::Lexer::TOKENS[:NUMBER] do
    before do
        @token = Puppet::Parser::Lexer::TOKENS[:NUMBER]
#        @regex = Regexp.new('^'+@token.regex.source+'$')
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

    it "should return the NAME token and the value" do
        @token.convert(stub("lexer"), "myval").should == [Puppet::Parser::Lexer::TOKENS[:NAME], "myval"]
    end
end

describe Puppet::Parser::Lexer::TOKENS[:COMMENT] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:COMMENT] }

    it "should match against lines starting with '#'" do
        @token.regex.should =~ "# this is a comment"
    end

    it "should be marked to get skipped" do
        @token.skip?.should be_true
    end

    it "should be marked to accumulate" do
        @token.accumulate?.should be_true
    end

    it "'s block should return the comment without the #" do
        @token.convert(@lexer,"# this is a comment")[1].should == "this is a comment"
    end
end

describe Puppet::Parser::Lexer::TOKENS[:MLCOMMENT] do
    before do
        @token = Puppet::Parser::Lexer::TOKENS[:MLCOMMENT]
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

    it "should increase the lexer current line number by the amount of lines spanned by the comment" do
        @lexer.expects(:line=).with(2)
        @token.convert(@lexer, "1\n2\n3")
    end

    it "should not greedily match comments" do
        match = @token.regex.match("/* first */ word /* second */")
        match[1].should == " first "
    end

    it "should be marked to accumulate" do
        @token.accumulate?.should be_true
    end

    it "'s block should return the comment without the comment marks" do
        @lexer.stubs(:line=).with(0)

        @token.convert(@lexer,"/* this is a comment */")[1].should == "this is a comment"
    end

end

describe Puppet::Parser::Lexer::TOKENS[:RETURN] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:RETURN] }

    it "should match against carriage returns" do
        @token.regex.should =~ "\n"
    end

    it "should be marked to initiate text skipping" do
        @token.skip_text.should be_true
    end

    it "should be marked to increment the line" do
        @token.incr_line.should be_true
    end
end

describe Puppet::Parser::Lexer::TOKENS[:SQUOTE] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:SQUOTE] }

    it "should match against single quotes" do
        @token.regex.should =~ "'"
    end

    it "should slurp the rest of the quoted string" do
        lexer = stub("lexer")
        lexer.expects(:slurpstring).with("myval").returns("otherval")
        @token.convert(lexer, "myval")
    end

    it "should return the SQTEXT token with the slurped string" do
        lexer = stub("lexer")
        lexer.stubs(:slurpstring).with("myval").returns("otherval")
        @token.convert(lexer, "myval").should == [Puppet::Parser::Lexer::TOKENS[:SQTEXT], "otherval"]
    end
end

describe Puppet::Parser::Lexer::TOKENS[:DQUOTE] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:DQUOTE] }

    it "should match against single quotes" do
        @token.regex.should =~ '"'
    end

    it "should slurp the rest of the quoted string" do
        lexer = stub("lexer")
        lexer.expects(:slurpstring).with("myval").returns("otherval")
        @token.convert(lexer, "myval")
    end

    it "should return the DQTEXT token with the slurped string" do
        lexer = stub("lexer")
        lexer.stubs(:slurpstring).with("myval").returns("otherval")
        @token.convert(lexer, "myval").should == [Puppet::Parser::Lexer::TOKENS[:DQTEXT], "otherval"]
    end
end

describe Puppet::Parser::Lexer::TOKENS[:VARIABLE] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:VARIABLE] }

    it "should match against alpha words prefixed with '$'" do
        @token.regex.should =~ '$this_var'
    end

    it "should return the VARIABLE token and the variable name stripped of the '$'" do
        @token.convert(stub("lexer"), "$myval").should == [Puppet::Parser::Lexer::TOKENS[:VARIABLE], "myval"]
    end
end

describe Puppet::Parser::Lexer::TOKENS[:REGEX] do
    before { @token = Puppet::Parser::Lexer::TOKENS[:REGEX] }

    it "should match against any expression enclosed in //" do
        @token.regex.should =~ '/this is a regex/'
    end

    it 'should not match if there is \n in the regex' do
        @token.regex.should_not =~ "/this is \n a regex/"
    end

    describe "when scanning" do
        def tokens_scanned_from(s)
            lexer = Puppet::Parser::Lexer.new
            lexer.string = s
            tokens = []
            lexer.scan do |name, value|
                tokens << value
            end
            tokens[0..-2]
        end

        it "should not consider escaped slashes to be the end of a regex" do
            tokens_scanned_from("$x =~ /this \\/ foo/").last[:value].should == Regexp.new("this / foo")
        end

        it "should not lex chained division as a regex" do
            tokens_scanned_from("$x = $a/$b/$c").any? {|t| t[:value].class == Regexp }.should == false
        end

        it "should accept a regular expression after NODE" do
            tokens_scanned_from("node /www.*\.mysite\.org/").last[:value].should == Regexp.new("www.*\.mysite\.org")
        end

        it "should accept regular expressions in a CASE" do
            s = %q{case $variable {
                "something": {$othervar = 4096 / 2}
                /regex/: {notice("this notably sucks")}
                }
            }
            tokens_scanned_from(s)[12][:value].should == Regexp.new("regex")
        end
 
   end


    it "should return the REGEX token and a Regexp" do
        @token.convert(stub("lexer"), "/myregex/").should == [Puppet::Parser::Lexer::TOKENS[:REGEX], Regexp.new(/myregex/)]
    end
end

describe Puppet::Parser::Lexer, "when lexing comments" do
    before { @lexer = Puppet::Parser::Lexer.new }

    it "should accumulate token in munge_token" do
        token = stub 'token', :skip => true, :accumulate? => true, :incr_line => nil, :skip_text => false

        token.stubs(:convert).with(@lexer, "# this is a comment").returns([token, " this is a comment"])
        @lexer.munge_token(token, "# this is a comment")
        @lexer.munge_token(token, "# this is a comment")

        @lexer.getcomment.should == " this is a comment\n this is a comment\n"
    end

    it "should add a new comment stack level on LBRACE" do
        @lexer.string = "{"

        @lexer.expects(:commentpush)

        @lexer.fullscan
    end

    it "should return the current comments on getcomment" do
        @lexer.string = "# comment"
        @lexer.fullscan

        @lexer.getcomment.should == "comment\n"
    end

    it "should discard the previous comments on blank line" do
        @lexer.string = "# 1\n\n# 2"
        @lexer.fullscan

        @lexer.getcomment.should == "2\n"
    end

    it "should skip whitespace before lexing the next token after a non-token" do
        @lexer.string = "/* 1\n\n */ \ntest"
        @lexer.fullscan.should be_like([[:NAME, "test"],[false,false]])
    end

    it "should not return comments seen after the current line" do
        @lexer.string = "# 1\n\n# 2"
        @lexer.fullscan

        @lexer.getcomment(1).should == ""
    end

    it "should return a comment seen before the current line" do
        @lexer.string = "# 1\n# 2"
        @lexer.fullscan

        @lexer.getcomment(2).should == "1\n2\n"
    end
end

# FIXME: We need to rewrite all of these tests, but I just don't want to take the time right now.
describe "Puppet::Parser::Lexer in the old tests" do
    before { @lexer = Puppet::Parser::Lexer.new }

    it "should do simple lexing" do
        strings = {
%q{\\} => [[:BACKSLASH,"\\"],[false,false]],
%q{simplest scanner test} => [[:NAME,"simplest"],[:NAME,"scanner"],[:NAME,"test"],[false,false]],
%q{returned scanner test
} => [[:NAME,"returned"],[:NAME,"scanner"],[:NAME,"test"],[false,false]]
        }
        strings.each { |str,ary|
            @lexer.string = str
            @lexer.fullscan().should be_like(ary)
        }
    end

    it "should correctly lex quoted strings" do
        strings = {
%q{a simple "scanner" test
} => [[:NAME,"a"],[:NAME,"simple"],[:DQTEXT,"scanner"],[:NAME,"test"],[false,false]],
%q{a simple 'single quote scanner' test
} => [[:NAME,"a"],[:NAME,"simple"],[:SQTEXT,"single quote scanner"],[:NAME,"test"],[false,false]],
%q{a harder 'a $b \c"'
} => [[:NAME,"a"],[:NAME,"harder"],[:SQTEXT,'a $b \c"'],[false,false]],
%q{a harder "scanner test"
} => [[:NAME,"a"],[:NAME,"harder"],[:DQTEXT,"scanner test"],[false,false]],
%q{a hardest "scanner \"test\""
} => [[:NAME,"a"],[:NAME,"hardest"],[:DQTEXT,'scanner "test"'],[false,false]],
%q{a hardestest "scanner \"test\"
"
} => [[:NAME,"a"],[:NAME,"hardestest"],[:DQTEXT,'scanner "test"
'],[false,false]],
%q{function("call")} => [[:NAME,"function"],[:LPAREN,"("],[:DQTEXT,'call'],[:RPAREN,")"],[false,false]]
}
        strings.each { |str,array|
            @lexer.string = str
            @lexer.fullscan().should be_like(array)
        }
    end

    it "should fail usefully" do
        strings = %w{
            ^
        }
        strings.each { |str|
            @lexer.string = str
            lambda { @lexer.fullscan() }.should raise_error(RuntimeError)
        }
    end

    it "should fail if the string is not set" do
        lambda { @lexer.fullscan() }.should raise_error(Puppet::LexError)
    end

    it "should correctly identify keywords" do
        @lexer.string = "case"
        @lexer.fullscan.should be_like([[:CASE, "case"], [false, false]])
    end

    it "should correctly match strings" do
        names = %w{this is a bunch of names}
        types = %w{Many Different Words A Word}
        words = %w{differently Cased words A a}

        names.each { |t|
            @lexer.string = t
            @lexer.fullscan.should be_like([[:NAME,t],[false,false]])
        }
        types.each { |t|
            @lexer.string = t
            @lexer.fullscan.should be_like([[:CLASSREF,t],[false,false]])
        }
    end

    it "should correctly parse names with numerals" do
       string = %w{1name name1 11names names11}

       string.each { |t|
            @lexer.string = t
            @lexer.fullscan.should be_like([[:NAME,t],[false,false]])
       }
    end

    it "should correctly parse empty strings" do
        bit = '$var = ""'

        @lexer.string = bit

        lambda { @lexer.fullscan }.should_not raise_error
    end

    it "should correctly parse virtual resources" do
        string = "@type {"

        @lexer.string = string

        @lexer.fullscan.should be_like([[:AT, "@"], [:NAME, "type"], [:LBRACE, "{"], [false,false]])
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

    it "should correctly handle fully qualified names" do
        @lexer.string = "class base { class sub::more {"

        @lexer.fullscan

        @lexer.namespace.should == "base::sub::more"

        @lexer.namepop

        @lexer.namespace.should == "base"
    end

    it "should correctly lex variables" do
        ["$variable", "$::variable", "$qualified::variable", "$further::qualified::variable"].each do |string|
            @lexer.string = string

            @lexer.scan do |t, s|
                t.should == :VARIABLE
                string.sub(/^\$/, '').should == s[:value]
                break
            end
        end
    end

    # #774
    it "should correctly parse the CLASSREF token" do
        string = ["Foo", "::Foo","Foo::Bar","::Foo::Bar"]

        string.each do |foo|
            @lexer.string = foo
            @lexer.fullscan.should be_like([[:CLASSREF, foo],[false,false]])
        end
    end

end

require 'puppettest/support/utils'
describe "Puppet::Parser::Lexer in the old tests when lexing example files" do
    extend PuppetTest
    extend PuppetTest::Support::Utils
    textfiles() do |file|
        it "should correctly lex #{file}" do
            lexer = Puppet::Parser::Lexer.new()
            lexer.file = file
            lambda { lexer.fullscan() }.should_not raise_error
        end
    end
end
