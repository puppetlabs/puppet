#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet'

class TestMounts < Test::Unit::TestCase
	include PuppetTest

    p = Puppet::Type.type(:mount).provide :fake, :parent => PuppetTest::FakeParsedProvider do
        @name = :fake
        apimethods :ensure

        attr_accessor :mounted

        def create
            @ensure = :present
        end

        def delete
            @ensure = :absent
            @mounted = false
        end

        def exists?
            if defined? @ensure and @ensure == :present
                true
            else
                false
            end
        end

        def mounted?
            self.mounted
        end

        def mount
            self.mounted = true
        end

        def unmount
            self.mounted = false
        end
    end

    FakeMountProvider = p

    @@fakeproviders[:mount] = p

    def setup
        super
        @realprovider = Puppet::Type.type(:mount).defaultprovider
        Puppet::Type.type(:mount).defaultprovider = FakeMountProvider
    end

    def teardown
        Puppet.type(:mount).clear
        Puppet::Type.type(:mount).defaultprovider = nil
        super
    end

    def mkmount
        mount = nil

        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :path => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        @realprovider.fields.each do |field|
            unless args.include? field
                args[field] = "fake%s" % @pcount
            end
        end

        assert_nothing_raised {
            mount = Puppet.type(:mount).create(args)
        }

        return mount
    end

    def test_simplemount
        mount = nil
        oldprv = Puppet.type(:mount).defaultprovider
        Puppet.type(:mount).defaultprovider = nil
        assert_nothing_raised {
            Puppet.type(:mount).defaultprovider.retrieve

            count = 0
            Puppet.type(:mount).each do |h|
                count += 1
            end

            assert_equal(0, count, "Found mounts in empty file somehow")
        }
        Puppet.type(:mount).defaultprovider = oldprv

        mount = mkmount

        assert_apply(mount)
        assert_events([], mount)

        assert_nothing_raised { mount.retrieve }

        assert_equal(:mounted, mount.is(:ensure))
    end

    # Make sure fs mounting behaves appropriately.  This is more a test of
    # whether things get mounted and unmounted based on the value of 'ensure'.
    def test_mountfs
        obj = mkmount

        assert_apply(obj)

        # Verify we can remove the mount
        assert_nothing_raised {
            obj[:ensure] = :absent
        }

        assert_events([:mount_deleted], obj)
        assert_events([], obj)

        # And verify it's gone
        assert(!obj.provider.mounted?, "Object is mounted after being removed")

        assert_nothing_raised {
            obj[:ensure] = :present
        }

        assert_events([:mount_created], obj)
        assert_events([], obj)

        assert(! obj.provider.mounted?, "Object is mounted incorrectly")

        assert_nothing_raised {
            obj[:ensure] = :mounted
        }

        assert_events([:mount_mounted], obj)
        assert_events([], obj)

        obj.retrieve
        assert(obj.provider.mounted?, "Object is not mounted")
    end
    
    def test_list
        list = nil
        assert_nothing_raised do
            list = Puppet::Type.type(:mount).list
        end
        
        assert(list.length > 0, "Did not return any mounts")
    end
end

# $Id$
