$:.unshift '../lib' if __FILE__ == $0 # Make this library first!

require 'blink'
require 'blink/parser/lexer'
require 'test/unit'
require 'blinktest.rb'

# $Id$

#%q{service("telnet") = \{
#    port => "23",
#    protocol => "tcp",
#    name => "telnet",
#\}
#} => [[:WORD, "service"], [:LPAREN, "("], [:DQUOTE, "\""], [:WORD, "telnet"], [:DQUOTE, "\""], [:RPAREN, ")"], [:EQUALS, "="], [:lbrace, "{"], [:WORD, "port"], [:FARROW, "=>"], [:DQUOTE, "\""], [:WORD, "23"], [:DQUOTE, "\""], [:COMMA, ","], [:WORD, "protocol"], [:FARROW, "=>"], [:DQUOTE, "\""], [:WORD, "tcp"], [:DQUOTE, "\""], [:COMMA, ","], [:WORD, "name"], [:FARROW, "=>"], [:DQUOTE, "\""], [:WORD, "telnet"], [:DQUOTE, "\""], [:COMMA, ","], [:RBRACE, "}"]]

class TestLexer < Test::Unit::TestCase
    def setup
        Blink.init(:debug => 1)
        @lexer = Blink::Parser::Lexer.new()
    end

    def test_simple_lex
        strings = {
%q{\\} => [[:BACKSLASH,"\\"],[false,false]],
%q{simplest scanner test} => [[:WORD,"simplest"],[:WORD,"scanner"],[:WORD,"test"],[false,false]],
%q{returned scanner test
} => [[:WORD,"returned"],[:WORD,"scanner"],[:WORD,"test"],[false,false]]
        }
        strings.each { |str,ary|
            @lexer.string = str
            assert_equal(
                ary,
                @lexer.fullscan()
            )
        }
    end

    def test_quoted_strings
        strings = {
%q{a simple "scanner" test
} => [[:WORD,"a"],[:WORD,"simple"],[:QTEXT,"scanner"],[:WORD,"test"],[false,false]],
%q{a harder "scanner test"
} => [[:WORD,"a"],[:WORD,"harder"],[:QTEXT,"scanner test"],[false,false]],
%q{a hardest "scanner \"test\""
} => [[:WORD,"a"],[:WORD,"hardest"],[:QTEXT,'scanner "test"'],[false,false]],
%q{function("call")} => [[:WORD,"function"],[:LPAREN,"("],[:QTEXT,'call'],[:RPAREN,")"],[false,false]]
}
        strings.each { |str,array|
            @lexer.string = str
            assert_equal(
                array,
                @lexer.fullscan()
            )
        }
    end

    def test_errors
        strings = %w{
            ^
            @
            <
            >
        }
        strings.each { |str|
            @lexer.string = str
            assert_raise(RuntimeError) {
                @lexer.fullscan()
            }
        }
    end

    def test_more_error
        assert_raise(TypeError) {
            @lexer.fullscan()
        }
    end

    def test_files
        textfiles() { |file|
            @lexer.file = file
            assert_nothing_raised() {
                @lexer.fullscan()
            }
        }
    end
end
