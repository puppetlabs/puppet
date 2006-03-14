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
when "Darwin", "OpenBSD": $skipsvcs = true
end

if $skipsvcs
    puts "Skipping service testing on %s" % Facter["operatingsystem"].value
else
#class TestInitService < Test::Unit::TestCase
class TestInitService
	include TestPuppet

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

    def tstsvcs
        case Facter["operatingsystem"].value.downcase
        when "solaris":
            return ["smtp", "xf"]
        end
    end

    def mksleeper(hash = {})
        hash[:name] = "sleeper"
        hash[:path] = File.join($puppetbase,"examples/root/etc/init.d")
        hash[:ensure] = true
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
            sleeper[:ensure] = 0
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
end

class TestLocalService < Test::Unit::TestCase
	include TestPuppet

    def teardown
        Puppet.type(:service).clear
        super
    end

    def mktestsvcs
        tstsvcs.collect { |svc,svcargs|
            args = svcargs.dup
            args[:name] = svc
            Puppet.type(:service).create(args)
        }
    end

    def tstsvcs
        case Facter["operatingsystem"].value.downcase
        when "solaris":
            case Facter["operatingsystemrelease"].value
            when "5.10":
                return {"smtp" => {}, "xfs" => {}}
            end
        when "debian":
            return {"hddtemp" => {}}
        when "centos":
            return {"cups" => {:hasstatus => true}}
        end

        Puppet.notice "No test services for %s-%s" %
            [Facter["operatingsystem"].value,
                Facter["operatingsystemrelease"].value]
        return []
    end

    def cycleservice(service)
        assert_nothing_raised() {
            service.retrieve
        }

        comp = newcomp("servicetst", service)
        service[:ensure] = true

        Puppet.info "Starting %s" % service.name
        assert_apply(service)

        # Some package systems background the work, so we need to give them
        # time to do their work.
        sleep(1.5)
        assert_nothing_raised() {
            service.retrieve
        }
        assert(service.insync?, "Service %s is not running" % service.name)

        # test refreshing it
        assert_nothing_raised() {
            service.refresh
        }

        assert(service.respond_to?(:refresh))

        # now stop it
        assert_nothing_raised() {
            service[:ensure] = :stopped
        }
        assert_nothing_raised() {
            service.retrieve
        }
        assert(!service.insync?(), "Service %s is not running" % service.name)
        Puppet.info "stopping %s" % service.name
        assert_events([:service_stopped], comp)
        sleep(1.5)
        assert_nothing_raised() {
            service.retrieve
        }
        assert(service.insync?, "Service %s has not stopped" % service.name)
    end

    def cycleenable(service)
        assert_nothing_raised() {
            service.retrieve
        }

        comp = newcomp("servicetst", service)
        service[:enable] = true

        Puppet.info "Enabling %s" % service.name
        assert_apply(service)

        # Some package systems background the work, so we need to give them
        # time to do their work.
        sleep(1.5)
        assert_nothing_raised() {
            service.retrieve
        }
        assert(service.insync?, "Service %s is not enabled" % service.name)

        # now stop it
        assert_nothing_raised() {
            service[:enable] = false
        }
        assert_nothing_raised() {
            service.retrieve
        }
        assert(!service.insync?(), "Service %s is not enabled" % service.name)
        Puppet.info "disabling %s" % service.name
        assert_events([:service_disabled], comp)
        sleep(1.5)
        assert_nothing_raised() {
            service.retrieve
        }
        assert(service.insync?, "Service %s has not been disabled" % service.name)
    end

    def test_status
        mktestsvcs.each { |svc|
            val = nil
            assert_nothing_raised("Could not get status") {
                val = svc.status
            }
            assert_instance_of(Symbol, val)
        }
    end

    unless Process.uid == 0
        puts "run as root to test service start/stop"
    else
        def test_servicestartstop
            mktestsvcs.each { |svc|
                startstate = nil
                assert_nothing_raised("Could not get status") {
                    startstate = svc.status
                }
                cycleservice(svc)

                svc[:ensure] = startstate
                assert_apply(svc)
                Puppet.type(:service).clear
                Puppet.type(:component).clear
            }
        end

        def test_serviceenabledisable
            mktestsvcs.each { |svc|
                startstate = nil
                svc[:check] = :enable
                assert_nothing_raised("Could not get status") {
                    startstate = svc.enabled?
                }
                cycleenable(svc)

                svc[:enable] = startstate
                assert_apply(svc)
                Puppet.type(:service).clear
                Puppet.type(:component).clear
            }
        end

        def test_serviceenableandrun
            mktestsvcs.each do |svc|
                startenable = nil
                startensure = nil
                svc[:check] = [:ensure, :enable]
                svc.retrieve
                assert_nothing_raised("Could not get status") {
                    startenable = svc.state(:enable).is
                    startensure = svc.state(:ensure).is
                }

                svc[:enable] = false
                svc[:ensure] = :stopped
                assert_apply(svc)

                sleep 1
                svc.retrieve
                assert(svc.insync?, "Service did not sync both states")

                svc[:enable] = true
                svc[:ensure] = :running
                assert_apply(svc)

                sleep 1
                svc.retrieve
                assert(svc.insync?, "Service did not sync both states")

                svc[:enable] = startenable
                svc[:ensure] = startensure
                assert_apply(svc)
                Puppet.type(:service).clear
                Puppet.type(:component).clear
            end
        end
    end
end
end

# $Id$
