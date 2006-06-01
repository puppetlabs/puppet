# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'puppet/type/zone'
require 'test/unit'
require 'facter'

class TestZone < Test::Unit::TestCase
	include TestPuppet

    # Zones can only be tested on solaris.
    if Facter["operatingsystem"].value == "Solaris"
    def test_list
        list = nil
        assert_nothing_raised {
            list = Puppet::Type.type(:zone).list
        }

        assert(! list.empty?, "Got no zones back")

        assert(list.find { |z| z[:name] == "global" }, "Could not find global zone")
    end

    def test_mkzone
        zone = nil

        base = tempfile()
        assert_nothing_raised {
            zone = Puppet::Type.type(:zone).create(
                :name => "fakezone",
                :base => base,
                :ensure => "present",
                :status => :running
            )
        }

        assert(zone, "Did not make zone")

        assert(! zone.insync?, "Zone is incorrectly in sync")

        assert_events([:zone_created], zone)

        assert_nothing_raised {
            zone.retrieve
        }

        assert(zone.insync?, "Zone is incorrectly out of sync")
    end
    end
end

# $Id$
