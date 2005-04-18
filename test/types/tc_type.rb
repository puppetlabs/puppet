if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

# $Id$

require 'blink/type'
require 'test/unit'

class TestType < Test::Unit::TestCase
    def test_typemethods
        Blink::Type.eachtype { |type|
            name = nil
            assert_nothing_raised() {
                name = type.name
            }

            assert(
                name
            )

            assert_equal(
                type,
                Blink::Type.type(name)
            )

            assert(
                type.namevar
            )
        }
    end
end
