if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

require 'blink'
require 'test/unit'

# $Id$

class TestStorage < Test::Unit::TestCase
    def setup
        Blink[:debug] = true
        Blink[:statefile] = "/var/tmp/blinkteststate"
    end

    def test_simple
        state = nil
        assert_nothing_raised {
            Blink::Storage.load
        }
        assert_nothing_raised {
            state = Blink::Storage.state(Blink::Type)
        }
        assert(state)
        state["/etc/passwd"] = ["md5","9ebebe0c02445c40b9dc6871b64ee416"]
        assert_nothing_raised {
            Blink::Storage.store
        }
        assert_nothing_raised {
            Blink::Storage.load
        }
        assert_equal(
            ["md5","9ebebe0c02445c40b9dc6871b64ee416"],
            Blink::Storage.state(Blink::Type)["/etc/passwd"]
        )
    end

    def test_instance
        file = nil
        state = nil
        assert_nothing_raised {
            file = Blink::Type::File.new(
                :path => "/etc/passwd"
            )
        }
        assert_nothing_raised {
            Blink::Storage.load
        }
        assert_nothing_raised {
            state = Blink::Storage.state(file)
        }
        assert(state)
    end

    def teardown
        system("rm -f %s" % Blink[:statefile])
    end
end
