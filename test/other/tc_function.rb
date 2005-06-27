if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet/function'
require 'puppet/fact'
require 'test/unit'

# $Id$

class TestFunctions < Test::Unit::TestCase
    def test_retrieve
        vars = %w{operatingsystem operatingsystemrelease}

        vars.each { |var|
            value = nil
            assert_nothing_raised() {
                value = Puppet::Function["fact"].call(var)
            }

            assert_equal(
                Puppet::Fact[var],
                value
            )
        }
    end
end
