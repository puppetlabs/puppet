# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
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
        host = nil
        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "culain",
                :ip => "192.168.0.3",
                :alias => "puppet"
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
        assert_nothing_raised {
            Puppet.type(:host).retrieve
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
end

# $Id$
