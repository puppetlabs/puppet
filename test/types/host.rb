#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

class TestHost < Test::Unit::TestCase
	include PuppetTest

    def setup
        super
        @hosttype = Puppet.type(:host)

        @provider = @hosttype.defaultprovider

        # Make sure they aren't using something funky like netinfo
        unless @provider.name == :parsed
            @hosttype.defaultprovider = @hosttype.provider(:parsed)
        end

        cleanup do @hosttype.defaultprovider = nil end

        oldpath = @provider.path
        cleanup do
            @provider.path = oldpath
        end
        @provider.path = tempfile()
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
        host = nil
        assert_nothing_raised {
            Puppet.type(:host).defaultprovider.retrieve

            count = 0
            @hosttype.each do |h|
                count += 1
            end

            assert_equal(0, count, "Found hosts in empty file somehow")
        }

        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "culain",
                :ip => "192.168.0.3"
            )
        }

        assert_apply(host)

        assert_nothing_raised { host.retrieve }

        assert_equal(:present, host.is(:ensure))
    end

    def test_moddinghost
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
        host = mkhost()
        assert_nothing_raised {
            host[:ensure] = :present
        }
        assert_events([:host_created], host)

        assert(host.exists?, "Host is not considered in sync")

        assert_equal(:present, host.is(:ensure))

        assert_nothing_raised {
            host[:ensure] = :absent
        }
        assert_events([:host_removed], host)

        text = host.provider.class.fileobj.read

        assert(! text.include?(host[:name]), "Host is still in text")
        host.retrieve
        assert_events([], host)
    end

    def test_modifyingfile
        hosts = []
        names = []
        3.times {
            h = mkhost()
            hosts << h
            names << h.name
        }
        assert_apply(*hosts)
        hosts.clear
        Puppet.type(:host).clear
        newhost = mkhost()
        names << newhost.name
        assert_apply(newhost)
        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newhost.retrieve
        }

        text = newhost.provider.class.fileobj.read

        # And verify that we have data for everything
        names.each { |name|
            assert(text.include?(name), "Host is not in file")
        }
    end
end

# $Id$
