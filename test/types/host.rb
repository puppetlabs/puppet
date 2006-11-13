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

        @default_file = @provider.default_target
        cleanup do
            @provider.default_target = @default_file
        end
        @target = tempfile()
        @provider.default_target = @target
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

    def test_list
        assert_nothing_raised do
            @hosttype.defaultprovider.prefetch
        end

        count = 0
        @hosttype.each do |h|
            count += 1
        end

        assert_equal(0, count, "Found hosts in empty file somehow")
    end

    def test_simplehost
        host = nil

        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "culain",
                :ip => "192.168.0.3"
            )
        }

        assert_events([:host_created], host)

        assert_nothing_raised { host.retrieve }

        assert_equal(:present, host.is(:ensure))

        host[:ensure] = :absent

        assert_events([:host_deleted], host)

        assert_nothing_raised { host.retrieve }

        assert_equal(:absent, host.is(:ensure))
    end

    def test_moddinghost
        host = mkhost()

        assert_events([:host_created], host)

        host.retrieve

        # This was a hard bug to track down.
        assert_instance_of(String, host.is(:ip))

        host[:alias] = %w{madstop kirby yayness}

        assert_events([:host_changed], host)

        host.retrieve

        assert_equal(%w{madstop kirby yayness}, host.is(:alias))
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
