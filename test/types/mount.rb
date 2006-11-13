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

        def self.default_target
            :yayness
        end

        def create
            @ensure = :present
            @model.class.validstates.each do |state|
                if value = @model.should(state)
                    self.send(state.to_s + "=", value)
                end
            end
        end

        def destroy
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
        @mount = Puppet::Type.type(:mount)
        @realprovider = @mount.defaultprovider
        @mount.defaultprovider = FakeMountProvider
    end

    def teardown
        Puppet.type(:mount).clear
        if @realprovider.respond_to?(:clear)
            @realprovider.clear
        end
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

        [@mount.validstates, @mount.parameters].flatten.each do |field|
            next if field == :provider
            next if field == :target
            next if field == :ensure
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
        mount = mkmount

        assert_apply(mount)
        mount.send(:states).each do |state|
            assert_equal(state.should, mount.provider.send(state.name),
                "%s was not set to %s" % [state.name, state.should])
        end
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
        assert_equal(:mounted, obj.is(:ensure))

        obj.retrieve
        assert(obj.provider.mounted?, "Object is not mounted")
    end
    
    # Darwin doesn't put its mount table into netinfo
    unless Facter.value(:operatingsystem) == "Darwin"
    def test_list
        list = nil
        assert(@mount.respond_to?(:list),
            "No list method defined for mount")

        assert_nothing_raised do
            list = Puppet::Type.type(:mount).list
        end
        
        assert(list.length > 0, "Did not return any mounts")

        root = list.find { |o| o[:name] == "/" }
        assert(root, "Could not find root root filesystem in list results")

        assert(root.is(:device), "Device was not set")
        assert(root.state(:device).value, "Device was not returned by value method")

        assert_nothing_raised do
            root.retrieve
        end

        assert(root.is(:device), "Device was not set")
        assert(root.state(:device).value, "Device was not returned by value method")
    end
    end

    # Make sure we actually remove the object from the file and such.
    # Darwin will actually write to netinfo here.
    if Facter.value(:operatingsystem) != "Darwin" or Process.uid == 0
    def test_removal
        # Reset the provider so that we're using the real thing
        @mount.defaultprovider = nil

        provider = @mount.defaultprovider
        assert(provider, "Could not retrieve default provider")

        if provider.respond_to?(:default_target)
            file = provider.default_target
            assert(FileTest.exists?(file),
                "FSTab %s does not exist" % file)

            # Now switch to ram, so we're just doing this there, not really on disk.
            provider.filetype = :ram
            #provider.target_object(file).write text
        end

        mount = mkmount

        mount[:ensure] = :present

        assert_events([:mount_created], mount)
        assert_events([], mount)

        mount[:ensure] = :absent
        assert_events([:mount_deleted], mount)
        assert_events([], mount)

        # Now try listing and making sure the object is actually gone.
        list = mount.provider.class.list
        assert(! list.find { |r| r[:name] == mount[:name] },
            "Mount was not actually removed")
    end
    end
end

# $Id$
