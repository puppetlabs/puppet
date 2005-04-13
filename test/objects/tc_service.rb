if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
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

        Blink[:debug] = 1
        assert_nothing_raised() {
            unless Blink::Objects::Service.has_key?("sleeper")
                Blink::Objects::Service.new(
                    :name => "sleeper",
                    :running => 1
                )
                Blink::Objects::Service.addpath(
                    File.join($blinkbase,"examples/root/etc/init.d")
                )
            end
            @sleeper = Blink::Objects::Service["sleeper"]
        }
    end

    def test_process_start
        assert_nothing_raised() {
            @sleeper[:running] = 1
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert_equal(
            Kernel.system("../examples/root/etc/init.d/sleeper status"),
            @sleeper.insync?()
        )
        assert_nothing_raised() {
            @sleeper.sync
        }
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert_equal(
            Kernel.system("../examples/root/etc/init.d/sleeper status"),
            @sleeper.insync?
        )
    end

    def test_process_evaluate
        assert_nothing_raised() {
            @sleeper[:running] = 1
        }
        assert_nothing_raised() {
            @sleeper.evaluate
        }
        # it really feels like this should be implicit...
        assert_nothing_raised() {
            @sleeper.retrieve
        }
        assert_equal(
            Kernel.system("../examples/root/etc/init.d/sleeper status"),
            @sleeper.insync?()
        )
        assert_equal(
            true,
            @sleeper.insync?()
        )
    end
end
