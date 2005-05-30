if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

# $Id$

require 'blink/type'
require 'test/unit'

class TestType < Test::Unit::TestCase
    def test_typemethods
        assert_nothing_raised() {
            Blink::Type.buildstatehash
        }

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

            assert_not_nil(
                type.states
            )

            assert_not_nil(
                type.validstates
            )

            assert(
                type.validparameter(type.namevar)
            )
        }
    end
end
