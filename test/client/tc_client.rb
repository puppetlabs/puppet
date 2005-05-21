if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk/"
end

require 'blink'
require 'blink/client'
require 'blink/fact'
require 'test/unit'
require 'blinktest.rb'

# $Id$

class TestClient < Test::Unit::TestCase
    def test_local
        client = nil
        assert_nothing_raised() {
            client = Blink::Client.new(:Local => true)
        }

        facts = %w{operatingsystem operatingsystemrelease}
        facts.each { |fact|
            assert_equal(
                Blink::Fact[fact],
                client.callfunc("fact",fact)
            )
        }
    end

    def test_files
    end
end
