require 'spec_helper'
require 'matchers/match_tokens2'
require 'puppet/pops'
require 'puppet/pops/parser/lexer2'

module EgrammarLexer2Spec
  def tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer2.new
    lexer.string = s
    lexer.fullscan[0..-2]
  end

  def epp_tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer2.new
    lexer.string = s
    lexer.fullscan_epp[0..-2]
  end
end

describe 'Lexer2' do
  include EgrammarLexer2Spec

  {
    :LISTSTART => '[',
    :RBRACK => ']',
    :LBRACE => '{',
    :RBRACE => '}',
    :WSLPAREN => '(', # since it is first on a line it is special (LPAREN handled separately)
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
    :OTHER => '\\',
    :FARROW => '=>',
    :PARROW => '+>',
    :APPENDS => '+=',
    :DELETES => '-=',
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
    it "should lex a token named #{name.to_s}" do
      expect(tokens_scanned_from(string)).to match_tokens2(name)
    end
  end

  it "should lex [ in position after non whitespace as LBRACK" do
    expect(tokens_scanned_from("a[")).to match_tokens2(:NAME, :LBRACK)
  end

  {
    "case"     => :CASE,
    "class"    => :CLASS,
    "default"  => :DEFAULT,
    "define"   => :DEFINE,
#    "import" => :IMPORT, # done as a function in egrammar
    "if"       => :IF,
    "elsif"    => :ELSIF,
    "else"     => :ELSE,
    "inherits" => :INHERITS,
    "node"     => :NODE,
    "and"      => :AND,
    "or"       => :OR,
    "undef"    => :UNDEF,
    "false"    => :BOOLEAN,
    "true"     => :BOOLEAN,
    "in"       => :IN,
    "unless"   => :UNLESS,
    "private"  => :PRIVATE,
    "type"     => :TYPE,
    "attr"     => :ATTR,
    "application"  => :APPLICATION,
    "consumes"     => :CONSUMES,
    "produces"     => :PRODUCES,
    "site"         => :SITE,
  }.each do |string, name|
    it "should lex a keyword from '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2(name)
    end
  end

  context 'when --no-tasks (the default)' do
    it "should lex a NAME from 'plan'" do
      expect(tokens_scanned_from('plan')).to match_tokens2(:NAME)
    end
  end

  context 'when --tasks' do
    before(:each) { Puppet[:tasks] = true }
    after(:each) { Puppet[:tasks] = false }

    it "should lex a keyword from 'plan'" do
      expect(tokens_scanned_from('plan')).to match_tokens2(:PLAN)
    end
  end

  # TODO: Complete with all edge cases
  [ 'A', 'A::B', '::A', '::A::B',].each do |string|
    it "should lex a CLASSREF on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:CLASSREF, string])
    end
  end

  # TODO: Complete with all edge cases
  [ 'a', 'a::b', '::a', '::a::b',].each do |string|
    it "should lex a NAME on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NAME, string])
    end
  end

  [ 'a-b', 'a--b', 'a-b-c', '_x'].each do |string|
    it "should lex a BARE WORD STRING on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:WORD, string])
    end
  end

  [ '_x::y', 'x::_y'].each do |string|
    it "should consider the bare word '#{string}' to be a WORD" do
      expect(tokens_scanned_from(string)).to match_tokens2(:WORD)
    end
  end

  { '-a'   =>      [:MINUS, :NAME],
    '--a'  =>      [:MINUS, :MINUS, :NAME],
    'a-'   =>      [:NAME, :MINUS],
    'a- b'   =>    [:NAME, :MINUS, :NAME],
    'a--'  =>      [:NAME, :MINUS, :MINUS],
    'a-$3' =>      [:NAME, :MINUS, :VARIABLE],
  }.each do |source, expected|
    it "should lex leading and trailing hyphens from #{source}" do
      expect(tokens_scanned_from(source)).to match_tokens2(*expected)
    end
  end

  { 'false'=>false, 'true'=>true}.each do |string, value|
    it "should lex a BOOLEAN on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:BOOLEAN, value])
    end
  end

  [ '0', '1', '2982383139'].each do |string|
    it "should lex a decimal integer NUMBER on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NUMBER, string])
    end
  end

  { ' 1' => '1', '1 ' => '1', ' 1 ' => '1'}.each do |string, value|
    it "should lex a NUMBER with surrounding space '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NUMBER, value])
    end
  end

  [ '0.0', '0.1', '0.2982383139', '29823.235', '10e23', '10e-23', '1.234e23'].each do |string|
    it "should lex a decimal floating point NUMBER on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NUMBER, string])
    end
  end

  [ '00', '01', '0123', '0777'].each do |string|
    it "should lex an octal integer NUMBER on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NUMBER, string])
    end
  end

  [ '0x0', '0x1', '0xa', '0xA', '0xabcdef', '0xABCDEF'].each do |string|
    it "should lex an hex integer NUMBER on the form '#{string}'" do
      expect(tokens_scanned_from(string)).to match_tokens2([:NUMBER, string])
    end
  end

  { "''"      => '',
    "'a'"     => 'a',
    "'a\\'b'" =>"a'b",
    "'a\\rb'" =>"a\\rb",
    "'a\\nb'" =>"a\\nb",
    "'a\\tb'" =>"a\\tb",
    "'a\\sb'" =>"a\\sb",
    "'a\\$b'" =>"a\\$b",
    "'a\\\"b'" =>"a\\\"b",
    "'a\\\\b'" =>"a\\b",
    "'a\\\\'" =>"a\\",
  }.each do |source, expected|
    it "should lex a single quoted STRING on the form #{source}" do
      expect(tokens_scanned_from(source)).to match_tokens2([:STRING, expected])
    end
  end

  { "''"      => [2, ""],
    "'a'"     => [3, "a"],
    "'a\\'b'" => [6, "a'b"],
    }.each do |source, expected|
      it "should lex a single quoted STRING on the form #{source} as having length #{expected[0]}" do
       length, value = expected
       expect(tokens_scanned_from(source)).to match_tokens2([:STRING, value, {:line => 1, :pos=>1, :length=> length}])
      end
    end

  { '""'      => '',
    '"a"'     => 'a',
    '"a\'b"'  => "a'b",
  }.each do |source, expected|
    it "should lex a double quoted STRING on the form #{source}" do
      expect(tokens_scanned_from(source)).to match_tokens2([:STRING, expected])
    end
  end

  { '"a$x b"'     => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>2 }],
                      [:VARIABLE, 'x',   {:line => 1, :pos=>3, :length=>2 }],
                      [:DQPOST,   ' b',  {:line => 1, :pos=>5, :length=>3 }]],

    '"a$x.b"'     => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>2 }],
                      [:VARIABLE, 'x',   {:line => 1, :pos=>3, :length=>2 }],
                      [:DQPOST,   '.b',  {:line => 1, :pos=>5, :length=>3 }]],

    '"$x.b"'      => [[:DQPRE,    '',    {:line => 1, :pos=>1, :length=>1 }],
                      [:VARIABLE, 'x',   {:line => 1, :pos=>2, :length=>2 }],
                      [:DQPOST,   '.b',  {:line => 1, :pos=>4, :length=>3 }]],

    '"a$x"'       => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>2 }],
                      [:VARIABLE, 'x',   {:line => 1, :pos=>3, :length=>2 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>5, :length=>1 }]],

    '"a${x}"'     => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>4 }],
                      [:VARIABLE, 'x',   {:line => 1, :pos=>5, :length=>1 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>7, :length=>1 }]],

    '"a${_x}"'    => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>4 }],
                      [:VARIABLE, '_x',  {:line => 1, :pos=>5, :length=>2 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>8, :length=>1 }]],

    '"a${y::_x}"' => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>4 }],
                      [:VARIABLE, 'y::_x',  {:line => 1, :pos=>5, :length=>5 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>11, :length=>1 }]],

    '"a${_x[1]}"' => [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>4 }],
                      [:VARIABLE, '_x',  {:line => 1, :pos=>5, :length=>2 }],
                      [:LBRACK,   '[',   {:line => 1, :pos=>7, :length=>1 }],
                      [:NUMBER,   '1',   {:line => 1, :pos=>8, :length=>1 }],
                      [:RBRACK,   ']',   {:line => 1, :pos=>9, :length=>1 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>11, :length=>1 }]],

    '"a${_x.foo}"'=> [[:DQPRE,    'a',   {:line => 1, :pos=>1, :length=>4 }],
                      [:VARIABLE, '_x',  {:line => 1, :pos=>5, :length=>2 }],
                      [:DOT,      '.',   {:line => 1, :pos=>7, :length=>1 }],
                      [:NAME,     'foo', {:line => 1, :pos=>8, :length=>3 }],
                      [:DQPOST,   '',    {:line => 1, :pos=>12, :length=>1 }]],
  }.each do |source, expected|
    it "should lex an interpolated variable 'x' from #{source}" do
      expect(tokens_scanned_from(source)).to match_tokens2(*expected)
    end
  end

  { '"$"'      => '$',
    '"a$"'     => 'a$',
    '"a$%b"'  => "a$%b",
    '"a$$"'  => "a$$",
    '"a$$%"'  => "a$$%",
  }.each do |source, expected|
    it "should lex interpolation including false starts #{source}" do
      expect(tokens_scanned_from(source)).to match_tokens2([:STRING, expected])
    end
  end

  it "differentiates between foo[x] and foo [x] (whitespace)" do
    expect(tokens_scanned_from("$a[1]")).to match_tokens2(:VARIABLE, :LBRACK, :NUMBER, :RBRACK)
    expect(tokens_scanned_from("$a [1]")).to match_tokens2(:VARIABLE, :LISTSTART, :NUMBER, :RBRACK)
    expect(tokens_scanned_from("a[1]")).to match_tokens2(:NAME, :LBRACK, :NUMBER, :RBRACK)
    expect(tokens_scanned_from("a [1]")).to match_tokens2(:NAME, :LISTSTART, :NUMBER, :RBRACK)
  end

  it "differentiates between '(' first on line, and not first on line" do
    expect(tokens_scanned_from("(")).to match_tokens2(:WSLPAREN)
    expect(tokens_scanned_from("\n(")).to match_tokens2(:WSLPAREN)
    expect(tokens_scanned_from("\n\r(")).to match_tokens2(:WSLPAREN)
    expect(tokens_scanned_from("\n\t(")).to match_tokens2(:WSLPAREN)
    expect(tokens_scanned_from("\n\r\t(")).to match_tokens2(:WSLPAREN)
    expect(tokens_scanned_from("\n\u00a0(")).to match_tokens2(:WSLPAREN)

    expect(tokens_scanned_from("x(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("\nx(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("\n\rx(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("\n\tx(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("\n\r\tx(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("\n\u00a0x(")).to match_tokens2(:NAME, :LPAREN)

    expect(tokens_scanned_from("x (")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("x\t(")).to match_tokens2(:NAME, :LPAREN)
    expect(tokens_scanned_from("x\u00a0(")).to match_tokens2(:NAME, :LPAREN)
  end

  it "skips whitepsace" do
    expect(tokens_scanned_from(" if if if ")).to match_tokens2(:IF, :IF, :IF)
    expect(tokens_scanned_from(" if \n\r\t\nif if ")).to match_tokens2(:IF, :IF, :IF)
    expect(tokens_scanned_from(" if \n\r\t\n\u00a0if\u00a0 if ")).to match_tokens2(:IF, :IF, :IF)
  end

  it "skips single line comments" do
    expect(tokens_scanned_from("if # comment\nif")).to match_tokens2(:IF, :IF)
  end

  ["if /* comment */\nif",
    "if /* comment\n */\nif",
    "if /*\n comment\n */\nif",
    ].each do |source|
    it "skips multi line comments" do
      expect(tokens_scanned_from(source)).to match_tokens2(:IF, :IF)
    end
  end

  it 'detects unterminated multiline comment' do
    expect { tokens_scanned_from("/* not terminated\nmultiline\ncomment") }.to raise_error(Puppet::ParseErrorWithIssue) { |e|
      expect(e.issue_code).to be(Puppet::Pops::Issues::UNCLOSED_MLCOMMENT.issue_code)
    }
  end

  { "=~" => [:MATCH, "=~ /./"],
    "!~" => [:NOMATCH, "!~ /./"],
    ","  => [:COMMA, ", /./"],

    "("       => [:WSLPAREN, "( /./"],
    "x ("     => [[:NAME, :LPAREN], "x ( /./"],
    "x\\t ("  => [[:NAME, :LPAREN], "x\t ( /./"],

    "[ (liststart)"             => [:LISTSTART, "[ /./"],
    "[ (LBRACK)"                => [[:NAME, :LBRACK], "a[ /./"],
    "[ (liststart after name)"  => [[:NAME, :LISTSTART], "a [ /./"],
    "{"  => [:LBRACE, "{ /./"],
    "+"  => [:PLUS, "+ /./"],
    "-"  => [:MINUS, "- /./"],
    "*"  => [:TIMES, "* /./"],
    ";"  => [:SEMIC, "; /./"],
  }.each do |token, entry|
    it "should lex regexp after '#{token}'" do
      expected = [entry[0], :REGEX].flatten
      expect(tokens_scanned_from(entry[1])).to match_tokens2(*expected)
    end
  end

  it "should lex a simple expression" do
    expect(tokens_scanned_from('1 + 1')).to match_tokens2([:NUMBER, '1'], :PLUS, [:NUMBER, '1'])
  end

  { "1"     => ["1 /./",       [:NUMBER, :DIV, :DOT, :DIV]],
    "'a'"   => ["'a' /./",     [:STRING, :DIV, :DOT, :DIV]],
    "true"  => ["true /./",    [:BOOLEAN, :DIV, :DOT, :DIV]],
    "false" => ["false /./",   [:BOOLEAN, :DIV, :DOT, :DIV]],
    "/./"   => ["/./ /./",     [:REGEX, :DIV, :DOT, :DIV]],
    "a"     => ["a /./",       [:NAME, :DIV, :DOT, :DIV]],
    "A"     => ["A /./",       [:CLASSREF, :DIV, :DOT, :DIV]],
    ")"     => [") /./",       [:RPAREN, :DIV, :DOT, :DIV]],
    "]"     => ["] /./",       [:RBRACK, :DIV, :DOT, :DIV]],
    "|>"     => ["|> /./",     [:RCOLLECT, :DIV, :DOT, :DIV]],
    "|>>"    => ["|>> /./",    [:RRCOLLECT, :DIV, :DOT, :DIV]],
    "$x"     => ["$x /1/",     [:VARIABLE, :DIV, :NUMBER, :DIV]],
    "a-b"    => ["a-b /1/",    [:WORD, :DIV, :NUMBER, :DIV]],
    '"a$a"'  => ['"a$a" /./',  [:DQPRE, :VARIABLE, :DQPOST, :DIV, :DOT, :DIV]],
  }.each do |token, entry|
    it "should not lex regexp after '#{token}'" do
      expect(tokens_scanned_from(entry[ 0 ])).to match_tokens2(*entry[ 1 ])
    end
  end

  it 'should lex assignment' do
    expect(tokens_scanned_from("$a = 10")).to match_tokens2([:VARIABLE, "a"], :EQUALS, [:NUMBER, '10'])
  end

# TODO: Tricky, and heredoc not supported yet
#  it "should not lex regexp after heredoc" do
#    tokens_scanned_from("1 / /./").should match_tokens2(:NUMBER, :DIV, :REGEX)
#  end

  it "should lex regexp at beginning of input" do
    expect(tokens_scanned_from(" /./")).to match_tokens2(:REGEX)
  end

  it "should lex regexp right of div" do
    expect(tokens_scanned_from("1 / /./")).to match_tokens2(:NUMBER, :DIV, :REGEX)
  end

  it 'should lex regexp with escaped slash' do
    scanned = tokens_scanned_from('/\//')
    expect(scanned).to match_tokens2(:REGEX)
    expect(scanned[0][1][:value]).to eql(Regexp.new('/'))
  end

  it 'should lex regexp with escaped backslash' do
    scanned = tokens_scanned_from('/\\\\/')
    expect(scanned).to match_tokens2(:REGEX)
    expect(scanned[0][1][:value]).to eql(Regexp.new('\\\\'))
  end

  it 'should lex regexp with escaped backslash followed escaped slash ' do
    scanned = tokens_scanned_from('/\\\\\\//')
    expect(scanned).to match_tokens2(:REGEX)
    expect(scanned[0][1][:value]).to eql(Regexp.new('\\\\/'))
  end

  it 'should lex regexp with escaped slash followed escaped backslash ' do
    scanned = tokens_scanned_from('/\\/\\\\/')
    expect(scanned).to match_tokens2(:REGEX)
    expect(scanned[0][1][:value]).to eql(Regexp.new('/\\\\'))
  end

  it 'should not lex regexp with escaped ending slash' do
    expect(tokens_scanned_from('/\\/')).to match_tokens2(:DIV, :OTHER, :DIV)
  end

  it "should accept newline in a regular expression" do
    scanned = tokens_scanned_from("/\n.\n/")
    # Note that strange formatting here is important
    expect(scanned[0][1][:value]).to eql(/
.
/)
  end

  context 'when lexer lexes heredoc' do
    it 'lexes tag, syntax and escapes, margin and right trim' do
      code = <<-CODE
      @(END:syntax/t)
      Tex\\tt\\n
      |- END
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2([:HEREDOC, 'syntax'], :SUBLOCATE, [:STRING, "Tex\tt\\n"])
    end

    it 'lexes "tag", syntax and escapes, margin, right trim and interpolation' do
      code = <<-CODE
      @("END":syntax/t)
      Tex\\tt\\n$var After
      |- END
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2(
        [:HEREDOC, 'syntax'],
        :SUBLOCATE,
        [:DQPRE, "Tex\tt\\n"],
        [:VARIABLE, "var"],
        [:DQPOST, " After"]
        )
    end

    it 'strips only last newline when using trim option' do
      code = <<-CODE.unindent
        @(END)
        Line 1
        
        Line 2
        -END
        CODE
      expect(tokens_scanned_from(code)).to match_tokens2(
        [:HEREDOC, ''],
        [:SUBLOCATE, ["Line 1\n", "\n", "Line 2\n"]],
        [:STRING, "Line 1\n\nLine 2"],
      )
    end

    it 'strips only one newline at the end when using trim option' do
      code = <<-CODE.unindent
        @(END)
        Line 1
        Line 2
        
        -END
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2(
        [:HEREDOC, ''],
        [:SUBLOCATE, ["Line 1\n", "Line 2\n", "\n"]],
        [:STRING, "Line 1\nLine 2\n"],
      )
    end

    context 'with bad syntax' do
      def expect_issue(code, issue)
        expect { tokens_scanned_from(code) }.to raise_error(Puppet::ParseErrorWithIssue) { |e|
          expect(e.issue_code).to be(issue.issue_code)
        }
      end

      it 'detects and reports HEREDOC_UNCLOSED_PARENTHESIS' do
        code = <<-CODE
        @(END:syntax/t
        Text
        |- END
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_UNCLOSED_PARENTHESIS)
      end

      it 'detects and reports HEREDOC_WITHOUT_END_TAGGED_LINE' do
        code = <<-CODE
        @(END:syntax/t)
        Text
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_WITHOUT_END_TAGGED_LINE)
      end

      it 'detects and reports HEREDOC_INVALID_ESCAPE' do
        code = <<-CODE
        @(END:syntax/x)
        Text
        |- END
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_INVALID_ESCAPE)
      end

      it 'detects and reports HEREDOC_INVALID_SYNTAX' do
        code = <<-CODE
        @(END:syntax/t/p)
        Text
        |- END
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_INVALID_SYNTAX)
      end

      it 'detects and reports HEREDOC_WITHOUT_TEXT' do
        code = '@(END:syntax/t)'
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_WITHOUT_TEXT)
      end

      it 'detects and reports HEREDOC_EMPTY_ENDTAG' do
        code = <<-CODE
        @("")
        Text
        |-END
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_EMPTY_ENDTAG)
      end

      it 'detects and reports HEREDOC_MULTIPLE_AT_ESCAPES' do
        code = <<-CODE
        @(END:syntax/tst)
        Tex\\tt\\n
        |- END
        CODE
        expect_issue(code, Puppet::Pops::Issues::HEREDOC_MULTIPLE_AT_ESCAPES)
      end
    end
  end
  context 'when not given multi byte characters' do
    it 'produces byte offsets for tokens' do
      code = <<-"CODE"
1 2\n3
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2(
        [:NUMBER, '1', {:line => 1, :offset => 0, :length=>1}],
        [:NUMBER, '2', {:line => 1, :offset => 2, :length=>1}],
        [:NUMBER, '3', {:line => 2, :offset => 4, :length=>1}]
      )
    end
  end

  context 'when dealing with multi byte characters' do
    it 'should support unicode characters' do
      code = <<-CODE
      "x\\u2713y"
      CODE
      # >= Ruby 1.9.3 reports \u
      expect(tokens_scanned_from(code)).to match_tokens2([:STRING, "x\u2713y"])
    end

    it 'should support adjacent short form unicode characters' do
      code = <<-CODE
      "x\\u2713\\u2713y"
      CODE
      # >= Ruby 1.9.3 reports \u
      expect(tokens_scanned_from(code)).to match_tokens2([:STRING, "x\u2713\u2713y"])
    end

    it 'should support unicode characters in long form' do
      code = <<-CODE
      "x\\u{1f452}y"
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2([:STRING, "x\u{1f452}y"])
    end

    it 'can escape the unicode escape' do
      code = <<-"CODE"
      "x\\\\u{1f452}y"
      CODE
      expect(tokens_scanned_from(code)).to match_tokens2([:STRING, "x\\u{1f452}y"])
    end

    it 'produces byte offsets that counts each byte in a comment' do
      code = <<-"CODE"
      # \u{0400}\na
      CODE
      expect(tokens_scanned_from(code.strip)).to match_tokens2([:NAME, 'a', {:line => 2, :offset => 5, :length=>1}])
    end

    it 'produces byte offsets that counts each byte in value token' do
      code = <<-"CODE"
      '\u{0400}'\na
      CODE
      expect(tokens_scanned_from(code.strip)).to match_tokens2(
        [:STRING, "\u{400}", {:line => 1, :offset => 0, :length=>4}],
        [:NAME, 'a', {:line => 2, :offset => 5, :length=>1}]
      )
    end

    it 'should not select LISTSTART token when preceded by multibyte chars' do
      # This test is sensitive to the number of multibyte characters and position of the expressions
      # within the string - it is designed to fail if the position is calculated on the byte offset of the '['
      # instead of the char offset.
      #
      code = "$a = '\u00f6\u00fc\u00fc\u00fc\u00fc\u00e4\u00e4\u00f6\u00e4'\nnotify {'x': message => B['dkda'] }\n"
      expect(tokens_scanned_from(code)).to match_tokens2(
        :VARIABLE, :EQUALS, :STRING,
        [:NAME, 'notify'], :LBRACE,
        [:STRING, 'x'], :COLON,
        :NAME, :FARROW, :CLASSREF, :LBRACK, :STRING, :RBRACK,
        :RBRACE)
    end
  end

  context 'when lexing epp' do
    it 'epp can contain just text' do
      code = <<-CODE
      This is just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(:EPP_START, [:RENDER_STRING, "      This is just text\n"])
    end

    it 'epp can contain text with interpolated rendered expressions' do
      code = <<-CODE
      This is <%= $x %> just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "      This is "],
      [:RENDER_EXPR, nil],
      [:VARIABLE, "x"],
      [:EPP_END, "%>"],
      [:RENDER_STRING, " just text\n"]
      )
    end

    it 'epp can contain text with trimmed interpolated rendered expressions' do
      code = <<-CODE
      This is <%= $x -%> just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "      This is "],
      [:RENDER_EXPR, nil],
      [:VARIABLE, "x"],
      [:EPP_END_TRIM, "-%>"],
      [:RENDER_STRING, "just text\n"]
      )
    end

    it 'epp can contain text with expressions that are not rendered' do
      code = <<-CODE
      This is <% $x=10 %> just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "      This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, " just text\n"]
      )
    end

    it 'epp can skip trailing space and newline in tail text' do
      # note that trailing whitespace is significant on one of the lines
      code = <<-CODE.unindent
      This is <% $x=10 -%>   
      just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "just text\n"]
      )
    end

    it 'epp can skip comments' do
      code = <<-CODE.unindent
      This is <% $x=10 -%>
      <%# This is an epp comment -%>
      just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "just text\n"]
      )
    end

    it 'epp comments does not strip left whitespace when preceding is right trim' do
      code = <<-CODE.unindent
      This is <% $x=10 -%>
         <%# This is an epp comment %>
      just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "   \njust text\n"]
      )
    end

    it 'epp comments does not strip left whitespace when preceding is not right trim' do
      code = <<-CODE.unindent
      This is <% $x=10 %>
          <%# This is an epp comment -%>
      just text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "\n    just text\n"]
      )
    end

    it 'epp comments can trim left with <%#-' do
      # test has 4 space before comment and 3 after it
      # check that there is 3 spaces before the 'and'
      #
      code = <<-CODE.unindent
      This is <% $x=10 -%>
      no-space-after-me:    <%#- This is an epp comment %>   and
      some text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "no-space-after-me:   and\nsome text\n"]
      )
    end

    it 'puppet comment in left trimming epp tag works when containing a new line' do
      # test has 4 space before comment and 3 after it
      # check that there is 3 spaces before the 'and'
      #
      code = <<-CODE.unindent
      This is <% $x=10 -%>
      no-space-after-me:    <%-# This is an puppet comment
        %>   and
      some text
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "no-space-after-me:"],
      [:RENDER_STRING, "   and\nsome text\n"]
      )
    end

    it 'epp can escape epp tags' do
      code = <<-CODE
      This is <% $x=10 -%>
      <%% this is escaped epp %%>
      CODE
      expect(epp_tokens_scanned_from(code)).to match_tokens2(
      :EPP_START,
      [:RENDER_STRING, "      This is "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NUMBER, "10"],
      [:RENDER_STRING, "      <% this is escaped epp %>\n"]
      )
    end

    context 'with bad epp syntax' do
      def expect_issue(code, issue)
        expect { epp_tokens_scanned_from(code) }.to raise_error(Puppet::ParseErrorWithIssue) { |e|
          expect(e.issue_code).to be(issue.issue_code)
        }
      end

      it 'detects and reports EPP_UNBALANCED_TAG' do
        expect_issue('<% asf', Puppet::Pops::Issues::EPP_UNBALANCED_TAG)
      end

      it 'detects and reports EPP_UNBALANCED_COMMENT' do
        expect_issue('<%# asf', Puppet::Pops::Issues::EPP_UNBALANCED_COMMENT)
      end

      it 'detects and reports EPP_UNBALANCED_EXPRESSION' do
        expect_issue('asf <%', Puppet::Pops::Issues::EPP_UNBALANCED_EXPRESSION)
      end
    end
  end

  context 'when parsing bad code' do
    def expect_issue(code, issue)
      expect { tokens_scanned_from(code) }.to raise_error(Puppet::ParseErrorWithIssue) do |e|
        expect(e.issue_code).to be(issue.issue_code)
      end
    end

    it 'detects and reports issue ILLEGAL_CLASS_REFERENCE' do
      expect_issue('A::3', Puppet::Pops::Issues::ILLEGAL_CLASS_REFERENCE)
    end

    it 'detects and reports issue ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE' do
      expect_issue('::A::3', Puppet::Pops::Issues::ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE)
    end

    it 'detects and reports issue ILLEGAL_FULLY_QUALIFIED_NAME' do
      expect_issue('::a::3', Puppet::Pops::Issues::ILLEGAL_FULLY_QUALIFIED_NAME)
    end

    it 'detects and reports issue ILLEGAL_NUMBER' do
     expect_issue('3g', Puppet::Pops::Issues::ILLEGAL_NUMBER)
    end

    it 'detects and reports issue INVALID_HEX_NUMBER' do
      expect_issue('0x3g', Puppet::Pops::Issues::INVALID_HEX_NUMBER)
    end

    it 'detects and reports issue INVALID_OCTAL_NUMBER' do
      expect_issue('038', Puppet::Pops::Issues::INVALID_OCTAL_NUMBER)
    end

    it 'detects and reports issue INVALID_DECIMAL_NUMBER' do
      expect_issue('4.3g', Puppet::Pops::Issues::INVALID_DECIMAL_NUMBER)
    end

    it 'detects and reports issue NO_INPUT_TO_LEXER' do
      expect { Puppet::Pops::Parser::Lexer2.new.fullscan }.to raise_error(Puppet::ParseErrorWithIssue) { |e|
        expect(e.issue_code).to be(Puppet::Pops::Issues::NO_INPUT_TO_LEXER.issue_code)
      }
    end

    it 'detects and reports issue UNCLOSED_QUOTE' do
      expect_issue('"asd', Puppet::Pops::Issues::UNCLOSED_QUOTE)
    end
  end

  context 'when dealing with non UTF-8 and Byte Order Marks (BOMs)' do
      {
      'UTF_8'      => [0xEF, 0xBB, 0xBF],
      'UTF_16_1'   => [0xFE, 0xFF],
      'UTF_16_2'   => [0xFF, 0xFE],
      'UTF_32_1'   => [0x00, 0x00, 0xFE, 0xFF],
      'UTF_32_2'   => [0xFF, 0xFE, 0x00, 0x00],
      'UTF_1'      => [0xF7, 0x64, 0x4C],
      'UTF_EBCDIC' => [0xDD, 0x73, 0x66, 0x73],
      'SCSU'       => [0x0E, 0xFE, 0xFF],
      'BOCU'       => [0xFB, 0xEE, 0x28],
      'GB_18030'   => [0x84, 0x31, 0x95, 0x33]
      }.each do |key, bytes|
        it "errors on the byte order mark for #{key} '[#{bytes.map() {|b| '%X' % b}.join(' ')}]'" do
          format_name = key.split('_')[0,2].join('-')
          bytes_str = "\\[#{bytes.map {|b| '%X' % b}.join(' ')}\\]"
          fix =  " - remove these from the puppet source"
          expect {
            tokens_scanned_from(bytes.pack('C*'))
          }.to raise_error(Puppet::ParseErrorWithIssue,
            /Illegal #{format_name} .* at beginning of input: #{bytes_str}#{fix}/)
        end

       it "can use a possibly 'broken' UTF-16 string without problems for #{key}" do
         format_name = key.split('_')[0,2].join('-')
         string = bytes.pack('C*').force_encoding('UTF-16')
         bytes_str = "\\[#{string.bytes.map {|b| '%X' % b}.join(' ')}\\]"
         fix =  " - remove these from the puppet source"
         expect {
           tokens_scanned_from(string)
         }.to raise_error(Puppet::ParseErrorWithIssue,
           /Illegal #{format_name} .* at beginning of input: #{bytes_str}#{fix}/)
       end
    end
  end
end

describe Puppet::Pops::Parser::Lexer2 do

  include PuppetSpec::Files

  # First line of Rune version of Rune poem at http://www.columbia.edu/~fdc/utf8/
  # characters chosen since they will not parse on Windows with codepage 437 or 1252
  # Section 3.2.1.3 of Ruby spec guarantees that \u strings are encoded as UTF-8
  # Runes (may show up as garbage if font is not available): ᚠᛇᚻ᛫ᛒᛦᚦ᛫ᚠᚱᚩᚠᚢᚱ᛫ᚠᛁᚱᚪ᛫ᚷᛖᚻᚹᛦᛚᚳᚢᛗ
  let (:rune_utf8) {
    "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2" +
    "\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA" +
    "\u16B3\u16A2\u16D7"
  }

  context 'when lexing files from disk' do
    it 'should always read files as UTF-8' do
      if Puppet.features.microsoft_windows? && Encoding.default_external == Encoding::UTF_8
        raise 'This test must be run in a codepage other than 65001 to validate behavior'
      end

      manifest_code = "notify { '#{rune_utf8}': }"
      manifest = file_containing('manifest.pp', manifest_code)
      lexed_file = described_class.new.lex_file(manifest)

      expect(lexed_file.string.encoding).to eq(Encoding::UTF_8)
      expect(lexed_file.string).to eq(manifest_code)
    end

    it 'currently errors when the UTF-8 BOM (Byte Order Mark) is present when lexing files' do
      bom = "\uFEFF"

        manifest_code = "#{bom}notify { '#{rune_utf8}': }"
        manifest = file_containing('manifest.pp', manifest_code)

        expect {
          described_class.new.lex_file(manifest)
        }.to raise_error(Puppet::ParseErrorWithIssue,
          'Illegal UTF-8 Byte Order mark at beginning of input: [EF BB BF] - remove these from the puppet source')
    end
  end

end
