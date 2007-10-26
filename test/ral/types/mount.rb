#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'mocha'

unless Facter.value(:operatingsystem) == "Darwin"
class TestMounts < PuppetTest::TestCase
	include PuppetTest

    p = Puppet::Type.type(:mount).provide :fake, :parent => PuppetTest::FakeParsedProvider do
        @name = :fake
        apimethods :ensure

        attr_accessor :mounted

        def self.default_target
            :yayness
        end

        def self.instances
            []
        end

        def create
            @ensure = :present
            @resource.class.validproperties.each do |property|
                if value = @resource.should(property)
                    self.send(property.to_s + "=", value)
                end
            end
        end

        def destroy
            @ensure = :absent
        end

        def exists?
            if defined? @ensure and @ensure == :present
                true
            else
                false
            end
        end

        def mounted?
            @ensure == :mounted
        end

        def mount
            @ensure = :mounted
        end

        def remount
        end

        def unmount
            @ensure = :present
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

        assert_nothing_raised {
            mount = Puppet.type(:mount).create(mkmount_args)
        }

        return mount
    end

    def mkmount_args
        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :name => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        [@mount.validproperties, @mount.parameters].flatten.each do |field|
            next if [:path, :provider, :target, :ensure, :remounts].include?(field)
            unless args.include? field
                args[field] = "fake%s" % @pcount
            end
        end

        return args
    end

    def test_simplemount
        mount = mkmount
        mount[:ensure] = :mounted

        assert_apply(mount)
        mount.send(:properties).each do |property|
            assert_equal(property.should, mount.provider.send(property.name),
                "%s was not set to %s" % [property.name, property.should])
        end
        assert_events([], mount)

        assert_nothing_raised { mount.retrieve }

        # Now modify a field
        mount[:dump] = 2
        mount[:options] = "defaults,ro"

        assert_events([:mount_changed,:mount_changed, :triggered], mount)
        assert_equal(2, mount.provider.dump, "Changes did not get flushed")
        assert_equal("defaults,ro", mount.provider.options, "Changes did not get flushed")

        # Now modify a field in addition to change :ensure.
        mount[:ensure] = :present
        mount[:options] = "defaults"

        assert_apply(mount)
        assert(! mount.provider.mounted?, "mount was still mounted")
        assert_equal("defaults", mount.provider.options)

        # Now remount it and make sure changes get flushed then, too.
        mount[:ensure] = :mounted
        mount[:options] = "aftermount"

        assert_apply(mount)
        assert(mount.provider.mounted?, "mount was not mounted")
        assert_equal("aftermount", mount.provider.options)
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

        assert_events([:mount_created, :triggered], obj)
        assert_events([], obj)

        assert(! obj.provider.mounted?, "Object is mounted incorrectly")

        assert_nothing_raised {
            obj[:ensure] = :mounted
        }

        assert_events([:mount_mounted, :triggered], obj)
        assert_events([], obj)

        current_values = nil
        assert_nothing_raised { current_values =  obj.retrieve }
        assert_equal(:mounted, current_values[obj.property(:ensure)])

        assert_nothing_raised { current_values =  obj.retrieve }
        assert(obj.provider.mounted?, "Object is not mounted")
    end

    def test_defaults
        obj = mkmount
        args = mkmount_args
        args.delete(:pass)
        args.delete(:dump)
        mount = nil

        assert_nothing_raised {
            mount = Puppet.type(:mount).create(args)
        }

        assert_equal(0, mount.should(:pass), "Did not set default for pass")
        assert_equal(0, mount.should(:dump), "Did not set default for dump")
    end
    
    # Darwin doesn't put its mount table into netinfo
    unless Facter.value(:operatingsystem) == "Darwin"
    def test_instances
        instances = nil
        assert(@mount.respond_to?(:instances),
            "No instances method defined for mount")

        assert_nothing_raised do
            instances = Puppet::Type.type(:mount).instances
        end
        
        assert(instances.length > 0, "Did not return any mounts")

        root = instances.find { |o| o[:name] == "/" }
        assert(root, "Could not find root root filesystem in instances results")
  
        current_values = nil
        assert_nothing_raised do
            current_values = root.retrieve
        end

        assert(current_values[root.property(:device)], "Device was not set")
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
            oldtype = provider.filetype
            provider.filetype = :ram
            cleanup { provider.filetype = oldtype }
            #provider.target_object(file).write text
        end

        mount = mkmount

        mount[:ensure] = :present

        assert_events([:mount_created, :triggered], mount)
        assert_events([], mount)

        mount[:ensure] = :absent
        assert_events([:mount_deleted], mount)
        assert_events([], mount)

        # Now try listing and making sure the object is actually gone.
        instances = mount.provider.class.instances
        assert(! instances.find { |r| r[:name] == mount[:name] },
            "Mount was not actually removed")
    end
    end

    # Make sure that the name gets correctly set if they set the path,
    # which used to be the namevar.
    def test_name_and_path
        mount = nil
        args = mkmount_args
        args[:name] = "mount_name"
        args[:path] = "mount_path"

        assert_nothing_raised do
            mount = @mount.create(args)
        end

        assert_equal("mount_path", mount[:name], "Name did not get copied over")
    end
    
    def test_refresh
        mount = mkmount
        mount[:ensure] = :mounted
        
        remounted = false
        mount.provider.meta_def(:remount) do
            remounted = true
        end
        
        # First make sure we correctly call the provider
        assert_nothing_raised do
            mount.refresh
        end
        assert(remounted, "did not call remount on provider")
        
        # then make sure it gets called during transactions
        remounted = false
        mount[:device] = "/dev/yayness"
        
        assert_apply(mount)
        
        assert(remounted, "did not remount when mount changed")

        # Now make sure it doesn't remount if the mount is just 'present'
        mount[:ensure] = :present
        mount[:device] = "/dev/funtest"
        remounted = false
        assert_apply(mount)

        assert(! remounted, "remounted even though not supposed to be mounted")
    end

    def test_no_default_for_ensure
        mount = mkmount
        mount.finish

        assert_nil(mount.should(:ensure), "Found default for ensure")
    end

    def disabled_test_retrieving_a_single_mount
        @mount.defaultprovider = nil

        provider = @mount.defaultprovider
        assert(provider, "Could not retrieve default provider")

        mount = Puppet::Type.type(:mount).create(:name => "/", :check => :all)
        values = nil
        assert_nothing_raised("Could not retrieve values for /") do
            values = mount.retrieve
        end
        values.each do |property, value|
            assert(value != :absent, "Got :absent for %s" % property.name)
        end
    end

    # #726 - when filesystems are mounted but absent, Puppet does not write them out.
    def test_mounted_but_absent
        mount = @mount.create(:name => "/testing", :ensure => :mounted, :provider => :fake, :device => "/dev/something")

        class << mount.provider
            def mounted?
                true
            end
        end

        mount.provider.destroy
        mount.provider.expects(:create)
        mount.provider.expects(:mount).never
        assert_apply(mount)
    end
end
end

