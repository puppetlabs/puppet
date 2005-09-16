if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestService < TestPuppet
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        sleeper = nil
        script = File.join($puppetbase,"examples/root/etc/init.d/sleeper")
        @status = script + " status"


        super
    end

    def teardown
        stopservices
        super
    end

    def mksleeper
        assert_nothing_raised() {
            return Puppet::Type::Service.create(
                :name => "sleeper",
                :path => File.join($puppetbase,"examples/root/etc/init.d"),
                :running => 1
            )
        }
    end

    def test_process_start
        sleeper = mksleeper
        # start it
        assert_nothing_raised() {
            sleeper[:running] = 1
        }
        assert_nothing_raised() {
            sleeper.retrieve
        }
        assert(!sleeper.insync?())
        assert_nothing_raised() {
            sleeper.sync
        }
        assert_nothing_raised() {
            sleeper.retrieve
        }
        assert(sleeper.insync?)

        # test refreshing it
        assert_nothing_raised() {
            sleeper.refresh
        }

        assert(sleeper.respond_to?(:refresh))

        # now stop it
        assert_nothing_raised() {
            sleeper[:running] = 0
        }
        assert_nothing_raised() {
            sleeper.retrieve
        }
        assert(!sleeper.insync?())
        assert_nothing_raised() {
            sleeper.sync
        }
        assert_nothing_raised() {
            sleeper.retrieve
        }
        assert(sleeper.insync?)
    end

    def test_FailOnNoPath
        serv = nil
        assert_nothing_raised {
            serv = Puppet::Type::Service.create(
                :name => "sleeper"
            )
        }

        assert_nil(serv)
        assert_nil(Puppet::Type::Service["sleeper"])
    end
end
