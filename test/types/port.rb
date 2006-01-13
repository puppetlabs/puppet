# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppettest'
require 'puppet'
require 'puppet/type/parsedtype/port'
require 'test/unit'
require 'facter'

class TestPort < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        @porttype = Puppet.type(:port)
        @oldfiletype = @porttype.filetype
    end

    def teardown
        @porttype.filetype = @oldfiletype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @porttype.filetype = Puppet::FileType.filetype(:ram)
    end

    def mkport
        port = nil
        assert_nothing_raised {
            port = Puppet.type(:port).create(
                :name => "puppet",
                :number => 8139,
                :protocols => "tcp",
                :description => "The port that Puppet runs on",
                :alias => "coolness"
            )
        }

        return port
    end

    def test_simplehost
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:port).retrieve)
        }

        assert_nothing_raised {
            port = Puppet.type(:port).create(
                :name => "puppet",
                :number => 8139,
                :protocols => "tcp",
                :description => "The port that Puppet runs on"
            )
        }

        assert_nothing_raised {
            Puppet.type(:port).store
        }

        assert_nothing_raised {
            assert(
                Puppet.type(:port).to_file.include?(
                    Puppet.type(:port).fileobj.read
                ),
                "File does not include all of our objects"
            )
        }
    end

    def test_portsparse
        assert_nothing_raised {
            Puppet.type(:port).retrieve
        }

        # Now just make we've got some ports we know will be there
        dns = @porttype["domain"]
        assert(dns, "Could not retrieve DNS port")

        assert_equal("53", dns.is(:number), "DNS number was wrong")
        %w{udp tcp}.each { |v|
            assert(dns.is(:protocols).include?(v), "DNS did not include proto %s" % v)
        }
    end

    def test_moddingport
        mkfaketype
        port = nil
        assert_nothing_raised {
            port = Puppet.type(:port).create(
                :name => "puppet",
                :number => 8139,
                :protocols => "tcp",
                :description => "The port that Puppet runs on"
            )
        }

        assert_events([:port_created], port)

        port[:protocols] = %w{tcp udp}

        assert_events([:port_changed], port)
    end

    def test_multivalues
        port = mkport
        assert_raise(Puppet::Error) {
            port[:protocols] = "udp tcp"
        }
        assert_raise(Puppet::Error) {
            port[:alias] = "puppetmasterd yayness"
        }
    end
end

# $Id$
