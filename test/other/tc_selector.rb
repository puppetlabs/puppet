if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet/selector'
require 'facter'
require 'test/unit'

# $Id$

class TestSelector < Test::Unit::TestCase
    def setup
        @os = Facter["operatingsystem"].value
        @hostname = Facter["hostname"].value

        Puppet[:loglevel] = :debug if __FILE__ == $0
    end

    def test_values
        selector = nil
        assert_nothing_raised() {
            selector = Puppet::Selector.new { |select|
                select.add("value1") {
                    Facter["hostname"].value == @hostname
                }
            }
        }

        assert_equal(
            "value1",
            selector.evaluate()
        )

    end
end
