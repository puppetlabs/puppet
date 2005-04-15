if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

require 'blink/fact'
require 'test/unit'

# $Id$

class TestFacts < Test::Unit::TestCase
    def test_newfact
        Blink[:debug] = true if __FILE__ == $0
        fact = nil
        assert_nothing_raised() {
            fact = Blink::Fact.new(
                :name => "funtest",
                :code => "echo funtest",
                :interpreter => "/bin/sh"
            )
        }
        assert_equal(
            "funtest",
            Blink::Fact["funtest"]
        )
    end
end
