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

        @provider = @porttype.defaultprovider

        # Make sure they aren't using something funky like netinfo
        unless @provider.name == :parsed
            @porttype.defaultprovider = @porttype.provider(:parsed)
        end

        cleanup do @porttype.defaultprovider = nil end

        oldpath = @provider.path
        cleanup do
            @provider.path = oldpath
        end
        @provider.path = tempfile()
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

    def test_moddingport
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
        port = mkport()
        assert_events([:port_created], port)

        port.delete(:alias)
        assert(! port.state(:alias))
        assert_events([:port_changed], port)

        assert_nothing_raised {
            port.retrieve
        }

        assert_equal(:present, port.is(:ensure))

        assert(port.state(:alias).is == :absent)

        port[:alias] = "yaytest"
        assert_events([:port_changed], port)
        port.retrieve
        assert(port.state(:alias).is == ["yaytest"])
    end
end

# $Id$
