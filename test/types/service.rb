if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestService < Test::Unit::TestCase
	include TestPuppet
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

    def mksleeper(hash = {})
        hash[:name] = "sleeper"
        hash[:path] = File.join($puppetbase,"examples/root/etc/init.d")
        hash[:running] = true
        hash[:type] = "init"
        assert_nothing_raised() {
            return Puppet::Type::Service.create(hash)
        }
    end

    def cyclesleeper(sleeper)
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

    def test_processStartWithPattern
        sleeper = mksleeper(:pattern => "bin/sleeper")

        cyclesleeper(sleeper)
    end

    def test_processStartWithStatus
        sleeper = mksleeper(:hasstatus => true)
        cyclesleeper(sleeper)
    end

    unless Process.uid == 0
        puts "run as root to test service enable/disable"
    else
        case Puppet::Type::Service.defaulttype
        when Puppet::ServiceTypes::InitSvc
        when Puppet::ServiceTypes::SMFSvc
            # yay
        else
            Puppet.notice "Not testing service type %s" %
                Puppet::Type::Service.defaulttype
        end
    end
end

# $Id$
