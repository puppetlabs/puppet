if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

# $Id$

require 'puppet/type'
require 'test/unit'

class TestType < Test::Unit::TestCase
    def test_typemethods
        assert_nothing_raised() {
            Puppet::Type.buildstatehash
        }

        Puppet::Type.eachtype { |type|
            name = nil
            assert_nothing_raised() {
                name = type.name
            }

            assert(
                name
            )

            assert_equal(
                type,
                Puppet::Type.type(name)
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
