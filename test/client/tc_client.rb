$:.unshift '../lib' if __FILE__ == $0 # Make this library first!

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
            client = Blink::Client::Local.new()
        }

        facts = %w{operatingsystem operatingsystemrelease}
        facts.each { |fact|
            assert_equal(
                Blink::Fact[fact],
                client.callfunc("retrieve",fact)
            )
        }
    end
end
