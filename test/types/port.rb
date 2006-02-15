# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
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
        pfile = tempfile()
        @porttype.path = pfile
    end

    def mkport
        port = nil

        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        assert_nothing_raised {
            port = Puppet.type(:port).create(
                :name => "puppet%s" % @pcount,
                :number => "813%s" % @pcount,
                :protocols => "tcp",
                :description => "The port that Puppet runs on",
                :alias => "coolness%s" % @pcount
            )
        }

        return port
    end

    def test_simpleport
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:port).retrieve)
        }

        port = mkport

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
        fakedata("data/types/ports").each { |file|
            @porttype.path = file
            Puppet.info "Parsing %s" % file
            assert_nothing_raised {
                @porttype.retrieve
            }

            # Now just make we've got some ports we know will be there
            dns = @porttype["domain"]
            assert(dns, "Could not retrieve DNS port")

            assert_equal("53", dns.is(:number), "DNS number was wrong")
            %w{udp tcp}.each { |v|
                assert(dns.is(:protocols).include?(v), "DNS did not include proto %s" % v)
            }

            @porttype.clear
        }
    end

    def test_moddingport
        mkfaketype
        port = nil
        port = mkport

        assert_events([:port_created], port)

        port.retrieve

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

    def test_removal
        mkfaketype
        port = mkport()
        assert_nothing_raised {
            port[:ensure] = :present
        }
        assert_events([:port_created], port)

        port.retrieve
        assert(port.insync?)
        assert_nothing_raised {
            port[:ensure] = :absent
        }

        assert_events([:port_removed], port)
        port.retrieve
        assert_events([], port)
    end

    def test_modifyingfile
        mkfaketype()

        ports = []
        names = []
        3.times {
            k = mkport()
            ports << k
            names << k.name
        }
        assert_apply(*ports)
        ports.clear
        Puppet.type(:port).clear
        newport = mkport()
        #newport[:ensure] = :present
        names << newport.name
        assert_apply(newport)
        Puppet.type(:port).clear
        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newport.retrieve
        }

        # And verify that we have data for everything
        names.each { |name|
            port = Puppet.type(:port)[name]
            assert(port)
            port.retrieve
            assert(port[:number], "port %s has no number" % name)
        }
    end

    def test_addingstates
        mkfaketype

        port = mkport()
        assert_events([:port_created], port)

        port.delete(:alias)
        assert(! port.state(:alias))
        assert_events([:port_changed], port)
        assert_nothing_raised {
            port.retrieve
        }

        assert(port.state(:alias).is == :absent)

        port[:alias] = "yaytest"
        assert_events([:port_changed], port)
        port.retrieve
        assert(port.state(:alias).is == ["yaytest"])
    end
end

# $Id$
