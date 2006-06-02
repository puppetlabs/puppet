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

    def setup
        super
        @@zones = []
    end

    def teardown
        super

        current = %x{zoneadm list -cp}.split("\n").collect { |line|
            ary = line.split(":")
            ary[1]
        }
        @@zones.each do |zone|
            if current.include?(zone)
                system("zonecfg -z #{zone} delete -F")
            end
        end
    end

    # Zones can only be tested on solaris.
    if Facter["operatingsystem"].value == "Solaris"

    def mkzone(name)
        zone = nil

        base = tempfile()
        Dir.mkdir(base)
        File.chmod(0700, base)
        root = File.join(base, "zonebase")
        assert_nothing_raised {
            zone = Puppet::Type.type(:zone).create(
                :name => name,
                :path => root,
                :ensure => "running"
            )
        }

        @@zones << name

        return zone
    end

    def test_list
        list = nil
        assert_nothing_raised {
            list = Puppet::Type.type(:zone).list
        }

        assert(! list.empty?, "Got no zones back")

        assert(list.find { |z| z[:name] == "global" }, "Could not find global zone")
    end

    def test_valueslice
        zone = mkzone("slicetest")

        state = zone.state(:ensure)

        slice = nil
        assert_nothing_raised {
            slice = state.class.valueslice(:absent, :installed).collect do |o|
                o[:name]
            end
        }


        assert_equal(slice, [:absent, :configured, :installed])
    end

    # Make sure the ensure stuff behaves as we expect
    def test_zoneensure
        zone = mkzone("ensurezone")

        state = zone.state(:ensure)

        assert(state, "Did not get ensure state")

        assert_nothing_raised {
            zone.retrieve
        }

        assert(! state.insync?, "State is somehow in sync")

        assert(state.up?, "State incorrectly thinks it is not moving up")

        zone.is = [:ensure, :configured]
        assert(state.up?, "State incorrectly thinks it is not moving up")
        zone[:ensure] = :absent
        assert(! state.up?, "State incorrectly thinks it is moving up")
    end

    # Make sure all mentioned methods actually exist.
    def test_zonemethods_exist
        methods = []
        zone = mkzone("methodtest")

        state = zone.state(:ensure)
        assert_nothing_raised {
            state.class.valueslice(:absent, :running).each do |st|
                [:up, :down].each do |m|
                    if st[m]
                        methods << st[m]
                    end
                end
            end
        }

        methods.each do |m|
            assert(Puppet::Type.type(:zone).method_defined?(m),
                "Zones do not define method %s" % m)
        end

    end

    if Process.uid == 0
    # Make sure our ensure process actually works.
    def test_ensure_sync
        zone = mkzone("ensuretesting")

        zone[:ensure] = :configured

        zone.retrieve
        assert_apply(zone)

        zone.retrieve

        assert(zone.insync?, "Zone is not insync")
    end

    def test_getconfig
        zone = mkzone("configtesting")

        base = tempfile()
        zone[:path] = base

        ip = "192.168.0.1"
        zone[:ip] = ip

        IO.popen("zonecfg -z configtesting -f -", "w") do |f|
            f.puts %{create -b
set zonepath=#{tempfile()}
set autoboot=true
add inherit-pkg-dir
set dir=/lib
end
add inherit-pkg-dir
set dir=/platform
end
add inherit-pkg-dir
set dir=/sbin
end
add inherit-pkg-dir
set dir=/opt/csw
end
add inherit-pkg-dir
set dir=/usr
end
add net
set address=#{ip}
set physical=bge0
end
}
        end

        assert_equal(0, $?, "Did not successfully create zone")

        #@@zones << "configtesting"

        assert_nothing_raised {
            zone.getconfig
        }

        # Now, make sure everything is right.
        assert_equal(%w{/sbin /usr /opt/csw /lib /platform}.sort,
            zone.is(:inherits).sort, "Inherited dirs did not get collected correctly."
        )

        assert_equal(["bge0:#{ip}"], zone.is(:ip),
            "IP addresses did not get collected correctly.")

        assert_equal("true", zone.is(:autoboot),
            "Autoboot did not get collected correctly.")
    end

    # Make sure we can do all the various and sundry configuring things.
    def test_configuring_zones
        zone = mkzone("configtesting")

        assert_nothing_raised {
            zone[:inherits] = "/usr"
        }

        zone[:ensure] = :configured

        zone.retrieve
        assert_apply(zone)

        zone.retrieve

        assert(zone.insync?, "Zone is not insync")

        p zone.state(:inherits)
    end

    # Just go through each method linearly and make sure it works.
    def test_each_method
        zone = mkzone("methodtesting")

        [[:configure, :configured],
            [:install, :installed],
            [:start, :running],
            [:stop, :installed],
            [:uninstall, :configured],
            [:unconfigure, :absent]
        ].each do |method, state|
            assert_nothing_raised {
                zone.retrieve
            }
            assert_nothing_raised {
                zone.send(method)
            }
            assert_nothing_raised {
                zone.retrieve
            }
            assert_equal(state, zone.is(:ensure),
                "Method %s did not correctly set state %s" %
                    [method, state])
        end
    end

    def test_mkzone
        zone = mkzone("testmaking")

        assert(zone, "Did not make zone")


        [:configured, :installed, :running, :installed, :absent].each do |value|
            assert_nothing_raised {
                zone[:ensure] = value
            }
            assert(! zone.insync?, "Zone is incorrectly in sync")

            assert_apply(zone)

            assert_nothing_raised {
                zone.retrieve
            }
            assert(zone.insync?, "Zone is incorrectly out of sync")
        end

        zone.retrieve

        assert_equal(:absent, zone.is(:ensure), "Zone is not absent")
    end
    end
    end
end

# $Id$
