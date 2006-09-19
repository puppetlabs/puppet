require 'puppet'
require 'puppet/parser/lexer'
require 'puppettest'

#%q{service("telnet") = \{
#    port => "23",
#    protocol => "tcp",
#    name => "telnet",
#\}
#} => [[:NAME, "service"], [:LPAREN, "("], [:DQUOTE, "\""], [:NAME, "telnet"], [:DQUOTE, "\""], [:RPAREN, ")"], [:EQUALS, "="], [:lbrace, "{"], [:NAME, "port"], [:FARROW, "=>"], [:DQUOTE, "\""], [:NAME, "23"], [:DQUOTE, "\""], [:COMMA, ","], [:NAME, "protocol"], [:FARROW, "=>"], [:DQUOTE, "\""], [:NAME, "tcp"], [:DQUOTE, "\""], [:COMMA, ","], [:NAME, "name"], [:FARROW, "=>"], [:DQUOTE, "\""], [:NAME, "telnet"], [:DQUOTE, "\""], [:COMMA, ","], [:RBRACE, "}"]]

class TestLexer < Test::Unit::TestCase
	include PuppetTest
    def setup
        super
        @lexer = Puppet::Parser::Lexer.new()
    end

    def test_simple_lex
        strings = {
%q{\\} => [[:BACKSLASH,"\\"],[false,false]],
%q{simplest scanner test} => [[:NAME,"simplest"],[:NAME,"scanner"],[:NAME,"test"],[false,false]],
%q{returned scanner test
} => [[:NAME,"returned"],[:NAME,"scanner"],[:NAME,"test"],[false,false]]
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
            assert_equal(
                array,
                @lexer.fullscan()
            )
        }
    end

    def test_errors
        strings = %w{
            ^
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
            Puppet::Type.allclear
        }
    end

    def test_strings
        names = %w{this is a bunch of names}
        types = %w{Many Different Words A Word}
        words = %w{differently Cased words A a}

        names.each { |t|
            @lexer.string = t
            assert_equal(
                [[:NAME,t],[false,false]],
                @lexer.fullscan
            )
        }
        types.each { |t|
            @lexer.string = t
            assert_equal(
                [[:TYPE,t],[false,false]],
                @lexer.fullscan
            )
        }
    end

    def test_emptystring
        bit = '$var = ""'

        assert_nothing_raised {
            @lexer.string = bit
        }

        assert_nothing_raised {
            @lexer.fullscan
        }
    end

    def test_collectlexing
        {"@" => :AT, "<|" => :LCOLLECT, "|>" => :RCOLLECT}.each do |string, token|
            assert_nothing_raised {
                @lexer.string = string
            }

            ret = nil
            assert_nothing_raised {
                ret = @lexer.fullscan
            }

            assert_equal([[token, string],[false, false]], ret)
        end
    end

    def test_collectabletype
        string = "@type {"

        assert_nothing_raised {
            @lexer.string = string
        }

        ret = nil
        assert_nothing_raised {
            ret = @lexer.fullscan
        }

        assert_equal([[:AT, "@"], [:NAME, "type"], [:LBRACE, "{"], [false,false]],ret)
    end
end

# $Id$
