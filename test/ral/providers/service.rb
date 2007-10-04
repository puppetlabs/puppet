#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

$skipsvcs = false
case Facter["operatingsystem"].value
when "Darwin", "OpenBSD": $skipsvcs = true
end

if $skipsvcs
    puts "Skipping service testing on %s" % Facter["operatingsystem"].value
else
class TestLocalService < Test::Unit::TestCase
	include PuppetTest

    def teardown
        Puppet.type(:service).clear
        super
    end

    def mktestsvcs
        list = tstsvcs.collect { |svc,svcargs|
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
            return {"hddtemp" => {:hasrestart => true}}
        when "centos":
            return {"cups" => {:hasstatus => true}}
        when "redhat":
            return {"saslauthd" => {:hasstatus => true}}
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

        comp = mk_configuration("servicetst", service)
        service[:ensure] = :running

        Puppet.info "Starting %s" % service.name
        assert_apply(service)

        # Some package systems background the work, so we need to give them
        # time to do their work.
        sleep(1.5)
        props = nil
        assert_nothing_raised() {
            props = service.retrieve
        }
        props.each do |prop, value|
            if prop.name == :ensure
                assert_equal(:running, value, "Service %s is not running" % service.name)
            end
        end

        # test refreshing it
        assert_nothing_raised() {
            service.refresh
        }

        # now stop it
        assert_nothing_raised() {
            service[:ensure] = :stopped
        }
        props.each do |prop, value|
            if prop.name == :ensure
                assert_equal(:running, value, "Service %s is not running" % service.name)
            end
        end
        Puppet.info "stopping %s" % service.name
        assert_events([:service_stopped], comp)
        sleep(1.5)
        assert_nothing_raised() {
            props = service.retrieve
        }
        props.each do |prop, value|
            if prop.name == :ensure
                assert_equal(:stopped, value, "Service %s is not running" % service.name)
            end
        end
    end

    def cycleenable(service)
        assert_nothing_raised() {
            service.retrieve
        }

        comp = mk_configuration("servicetst", service)
        service[:enable] = true

        Puppet.info "Enabling %s" % service.name
        assert_apply(service)

        # Some package systems background the work, so we need to give them
        # time to do their work.
        sleep(1.5)
        props = nil
        assert_nothing_raised() {
            props = service.retrieve
        }
        props.each do |prop, value|
            if prop.name == :enable
                assert_equal(value, :true, "Service %s is not enabled" % service.name)
            end
        end

        # now disable it
        assert_nothing_raised() {
            service[:enable] = false
        }
        assert_nothing_raised() {
            props = service.retrieve
        }
        props.each do |prop, value|
            assert_equal(value, :true, "Service %s is already disabled" % service.name)
        end
        Puppet.info "disabling %s" % service.name
        assert_events([:service_disabled], comp)
        sleep(1.5)
        assert_nothing_raised() {
            props = service.retrieve
        }
        props.each do |prop, value|
            assert_equal(value, :false, "Service %s is still enabled" % service.name)
        end
    end

    def test_status
        mktestsvcs.each { |svc|
            val = nil
            assert_nothing_raised("Could not get status") {
                val = svc.provider.status
            }
            assert_instance_of(Symbol, val)
        }
    end

    unless Puppet::Util::SUIDManager.uid == 0
        puts "run as root to test service start/stop"
    else
        def test_servicestartstop
            mktestsvcs.each { |svc|
                startproperty = nil
                assert_nothing_raised("Could not get status") {
                    startproperty = svc.provider.status
                }
                cycleservice(svc)

                svc[:ensure] = startproperty
                assert_apply(svc)
                Puppet.type(:component).clear
            }
        end

        def test_serviceenabledisable
            mktestsvcs.each { |svc|
                assert(svc[:name], "Service has no name")
                startproperty = nil
                svc[:check] = :enable
                assert_nothing_raised("Could not get status") {
                    startproperty = svc.provider.enabled?
                }
                cycleenable(svc)

                svc[:enable] = startproperty
                assert_apply(svc)
                Puppet.type(:component).clear
            }
        end

        def test_serviceenableandrun
            mktestsvcs.each do |svc|
                startenable = nil
                startensure = nil
                svc[:check] = [:ensure, :enable]
                properties = nil
                assert_nothing_raised("Could not get status") {
                    properties = svc.retrieve
                }
                initial = properties.dup

                svc[:enable] = false
                svc[:ensure] = :stopped
                assert_apply(svc)

                sleep 1
                assert_nothing_raised("Could not get status") {
                    properties = svc.retrieve
                }
                properties.each do |prop, value|
                    assert(prop.insync?(value), "Service did not sync %s property" % prop.name)
                end

                svc[:enable] = true
                svc[:ensure] = :running
                assert_apply(svc)

                sleep 1
                assert_nothing_raised("Could not get status") {
                    properties = svc.retrieve
                }
                assert(svc.insync?(properties), "Service did not sync both properties")

                initial.each do |prop, value|
                    svc[prop.name] = value
                end
                assert_apply(svc)
                Puppet.type(:component).clear
            end
        end
    end
end
end

