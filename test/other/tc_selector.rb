if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

require 'blink/selector'
require 'test/unit'

# $Id$

class TestSelector < Test::Unit::TestCase
    def setup
        @os = Blink::Fact["operatingsystem"]
        @hostname = Blink::Fact["hostname"]
    end

    def test_values
        Blink[:debug] = 1

        selector = nil
        assert_nothing_raised() {
            selector = Blink::Selector.new { |select|
                select.add("value1") {
                    Blink::Fact["hostname"] == @hostname
                }
            }
        }

        assert_equal(
            "value1",
            selector.evaluate()
        )

    end
end
