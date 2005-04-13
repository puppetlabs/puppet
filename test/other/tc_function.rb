if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

require 'blink/function'
require 'blink/fact'
require 'test/unit'

# $Id$

class TestFunctions < Test::Unit::TestCase
    def test_retrieve
        vars = %w{operatingsystem operatingsystemrelease}

        vars.each { |var|
            value = nil
            assert_nothing_raised() {
                value = Blink::Function["retrieve"].call(var)
            }

            assert_equal(
                Blink::Fact[var],
                value
            )
        }
    end
end
