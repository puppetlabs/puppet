if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

$skipsvcs = false
case Facter["operatingsystem"].value
when "Darwin": $skipsvcs = true
end

if $skipsvcs
    puts "Skipping service testing on %s" % Facter["operatingsystem"].value
else
class TestService < Test::Unit::TestCase
	include TestPuppet
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        super
        sleeper = nil
        script = File.join($puppetbase,"examples/root/etc/init.d/sleeper")
        @init = File.join($puppetbase,"examples/root/etc/init.d")
        @status = script + " status"
    end

    def teardown
        super
        stopservices
    end

    def mksleeper(hash = {})
        hash[:name] = "sleeper"
        hash[:path] = File.join($puppetbase,"examples/root/etc/init.d")
        hash[:running] = true
        hash[:hasstatus] = true
        #hash[:type] = "init"
        assert_nothing_raised() {
            return Puppet.type(:service).create(hash)
        }
    end

    def cyclesleeper(sleeper)
        assert_nothing_raised() {
            sleeper.retrieve
        }
        assert(!sleeper.insync?())

        comp = newcomp(sleeper)

        assert_events([:service_started], comp)
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
        assert_events([:service_stopped], comp)
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

    def test_invalidpathsremoved
        sleeper = mksleeper()
        fakedir = [@init, "/thisdirnoexist"]
        sleeper[:path] = fakedir

        assert(! sleeper[:path].include?(fakedir))
    end

    #unless Process.uid == 0
    #    puts "run as root to test service enable/disable"
    #else
    #    case Puppet.type(:service).defaulttype
    #    when Puppet::ServiceTypes::InitSvc
    #    when Puppet::ServiceTypes::SMFSvc
    #        # yay
    #    else
    #        Puppet.notice "Not testing service type %s" %
    #            Puppet.type(:service).defaulttype
    #    end
    #end
end
end

# $Id$
