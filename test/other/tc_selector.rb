if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet/selector'
require 'test/unit'

# $Id$

class TestSelector < Test::Unit::TestCase
    def setup
        @os = Puppet::Fact["operatingsystem"]
        @hostname = Puppet::Fact["hostname"]

        Puppet[:loglevel] = :debug if __FILE__ == $0
    end

    def test_values
        selector = nil
        assert_nothing_raised() {
            selector = Puppet::Selector.new { |select|
                select.add("value1") {
                    Puppet::Fact["hostname"] == @hostname
                }
            }
        }

        assert_equal(
            "value1",
            selector.evaluate()
        )

    end
end
