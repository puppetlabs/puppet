if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

require 'blink'
require 'test/unit'

# $Id$

class TestService < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @sleeper = nil
        script = File.join($blinkbase,"examples/root/etc/init.d/sleeper")
        @status = script + " status"

        Blink[:debug] = 1
        assert_nothing_raised() {
            unless Blink::Type::Service.has_key?("sleeper")
                Blink::Type::Service.new(
                    :name => "sleeper",
                    :running => 1
                )
                Blink::Type::Service.addpath(
                    File.join($blinkbase,"examples/root/etc/init.d")
                )
            end
            @sleeper = Blink::Type::Service["sleeper"]
        }
    end

    def test_process_start
        # start it
        assert_nothing_raised() {
            @sleeper[:running] = 1
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert(!@sleeper.insync?())
        assert_nothing_raised() {
            @sleeper.sync
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert(@sleeper.insync?)

        # now stop it
        assert_nothing_raised() {
            @sleeper[:running] = 0
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert(!@sleeper.insync?())
        assert_nothing_raised() {
            @sleeper.sync
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert(@sleeper.insync?)
    end
    def teardown
        Kernel.system("pkill sleeper")
    end
end
