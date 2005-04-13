$:.unshift '../lib' if __FILE__ == $0 # Make this library first!

require 'blink'
require 'blink/parser/parser'
require 'test/unit'
require 'blinktest.rb'

# $Id$

class TestParser < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        Blink.init(:debug => 1, :parseonly => true)
        #@lexer = Blink::Parser::Lexer.new()
        @parser = Blink::Parser::Parser.new()
    end

    def test_each_file
        textfiles { |file|
            Blink.debug("parsing %s" % file)
            assert_nothing_raised() {
                @parser.file = file
                @parser.parse
            }
        }
    end
end
