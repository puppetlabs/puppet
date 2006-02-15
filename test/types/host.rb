# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

class TestHost < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        # god i'm lazy
        @hosttype = Puppet.type(:host)
        @oldhosttype = @hosttype.filetype
    end

    def teardown
        @hosttype.filetype = @oldhosttype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @hosttype.filetype = Puppet::FileType.filetype(:ram)
    end

    def mkhost
        if defined? @hcount
            @hcount += 1
        else
            @hcount = 1
        end
        host = nil
        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "fakehost%s" % @hcount,
                :ip => "192.168.27.%s" % @hcount,
                :alias => "alias%s" % @hcount
            )
        }

        return host
    end

    def test_simplehost
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:host).retrieve)
        }

        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "culain",
                :ip => "192.168.0.3"
            )
        }

        assert_nothing_raised {
            Puppet.type(:host).store
        }

        assert_nothing_raised {
            assert(
                Puppet.type(:host).to_file.include?(
                    Puppet.type(:host).fileobj.read
                ),
                "File does not include all of our objects"
            )
        }
    end

    def test_hostsparse
        fakedata("data/types/hosts").each { |file|
            @hosttype.path = file
            Puppet.info "Parsing %s" % file
            assert_nothing_raised {
                Puppet.type(:host).retrieve
            }

            @hosttype.clear
        }
    end

    def test_moddinghost
        mkfaketype
        host = mkhost()

        assert_events([:host_created], host)

        host.retrieve

        # This was a hard bug to track down.
        assert_instance_of(String, host.is(:ip))

        host[:alias] = %w{madstop kirby yayness}

        assert_events([:host_changed], host)
    end

    def test_aliasisstate
        assert_equal(:state, @hosttype.attrtype(:alias))
    end

    def test_multivalues
        host = mkhost
        assert_raise(Puppet::Error) {
            host[:alias] = "puppetmasterd yayness"
        }
    end

    def test_puppetalias
        host = mkhost()

        assert_nothing_raised {
            host[:alias] = "testing"
        }

        same = host.class["testing"]
        assert(same, "Could not retrieve by alias")
    end

    def test_removal
        mkfaketype
        host = mkhost()
        assert_nothing_raised {
            host[:ensure] = :present
        }
        assert_events([:host_created], host)

        host.retrieve
        assert(host.insync?)
        assert_nothing_raised {
            host[:ensure] = :absent
        }

        assert_events([:host_removed], host)
        host.retrieve
        assert_events([], host)
    end

    def test_modifyingfile
        hostfile = tempfile()
        Puppet.type(:host).path = hostfile

        hosts = []
        names = []
        3.times {
            h = mkhost()
            #h[:ensure] = :present
            #h.retrieve
            hosts << h
            names << h.name
        }
        assert_apply(*hosts)
        hosts.clear
        Puppet.type(:host).clear
        newhost = mkhost()
        #newhost[:ensure] = :present
        names << newhost.name
        assert_apply(newhost)
        Puppet.type(:host).clear
        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newhost.retrieve
        }

        # And verify that we have data for everything
        names.each { |name|
            host = Puppet.type(:host)[name]
            assert(host)
            assert(host[:ip])
        }
    end
end

# $Id$
