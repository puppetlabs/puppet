#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-12.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppettest/support/utils'
require 'puppettest/fileparsing'

module ParsedMountTesting
    include PuppetTest::Support::Utils
    include PuppetTest::FileParsing

    def fake_fstab
        os = Facter['operatingsystem']
        if os == "Solaris"
            name = "solaris.fstab"
        elsif os == "FreeBSD"
            name = "freebsd.fstab"
        else
            # Catchall for other fstabs
            name = "linux.fstab"
        end
        oldpath = @provider_class.default_target
        return fakefile(File::join("data/types/mount", name))
    end

    def mkmountargs
        mount = nil

        if defined? @pcount
            @pcount += 1
        else
            @pcount = 1
        end
        args = {
            :name => "/fspuppet%s" % @pcount,
            :device => "/dev/dsk%s" % @pcount,
        }

        @provider_class.fields(:parsed).each do |field|
            unless args.include? field
                args[field] = "fake%s%s" % [field, @pcount]
            end
        end

        return args
    end

    def mkmount
        hash = mkmountargs()
        #hash[:provider] = @provider_class.name

        fakeresource = stub :type => :mount, :name => hash[:name]
        fakeresource.stubs(:[]).with(:name).returns(hash[:name])
        fakeresource.stubs(:should).with(:target).returns(nil)

        mount = @provider_class.new(fakeresource)
        hash[:record_type] = :parsed
        hash[:ensure] = :present
        mount.property_hash = hash

        return mount
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @provider.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
    end
end

provider_class = Puppet::Type.type(:mount).provider(:parsed)

describe provider_class do
    before :each do
        @mount_class = Puppet::Type.type(:mount)
        @provider_class = @mount_class.provider(:parsed)
    end


    describe provider_class do
        include ParsedMountTesting

        it "should be able to parse all of the example mount tabs" do
            tab = fake_fstab
            @provider = @provider_class

            # LAK:FIXME Again, a relatively bad test, but I don't know how to rspec-ify this.
            # I suppose this is more of an integration test?  I dunno.
            fakedataparse(tab) do
                # Now just make we've got some mounts we know will be there
                hashes = @provider_class.target_records(tab).find_all { |i| i.is_a? Hash }
                (hashes.length > 0).should be_true
                root = hashes.find { |i| i[:name] == "/" }

                proc { @provider_class.to_file(hashes) }.should_not raise_error
            end
        end

        # LAK:FIXME I can't mock Facter because this test happens at parse-time.
        it "should default to /etc/vfstab on Solaris and /etc/fstab everywhere else" do
            should = case Facter.value(:operatingsystem)
                when "Solaris"; "/etc/vfstab"
                else
                    "/etc/fstab"
                end
            Puppet::Type.type(:mount).provider(:parsed).default_target.should == should
        end

        it "should not crash on incomplete lines in fstab" do
            parse = @provider_class.parse <<-FSTAB
/dev/incomplete
/dev/device       name
            FSTAB

            lambda{ @provider_class.to_line(parse[0]) }.should_not raise_error
        end
    end

    describe provider_class, " when mounting an absent filesystem" do
        include ParsedMountTesting

        # #730 - Make sure 'flush' is called when a mount is moving from absent to mounted
        it "should flush the fstab to disk" do
            mount = mkmount

            # Mark the mount as absent
            mount.property_hash[:ensure] = :absent

            mount.stubs(:mountcmd) # just so we don't actually try to mount anything

            mount.expects(:flush)
            mount.mount
        end
    end

    describe provider_class, " when modifying the filesystem tab" do
        include ParsedMountTesting
        before do
            Puppet.settings.stubs(:use)
            # Never write to disk, only to RAM.
            #@provider_class.stubs(:filetype).returns(Puppet::Util::FileType.filetype(:ram))
            @provider_class.stubs(:target_object).returns(Puppet::Util::FileType.filetype(:ram).new("eh"))

            @mount = mkmount
            @target = @provider_class.default_target
        end

        it "should write the mount to disk when :flush is called" do
            old_text = @provider_class.target_object(@provider_class.default_target).read
            
            @mount.flush

            text = @provider_class.target_object(@provider_class.default_target).read
            text.should == old_text + @mount.class.to_line(@mount.property_hash) + "\n"
        end
    end

    describe provider_class, " when parsing information about the root filesystem" do
        confine "Mount type not tested on Darwin" => Facter["operatingsystem"].value != "Darwin"
        include ParsedMountTesting

        before do
            @mount = @mount_class.new :name => "/"
            @provider = @mount.provider
        end

        it "should have a filesystem tab" do
            FileTest.should be_exist(@provider_class.default_target)
        end

        it "should find the root filesystem" do
            @provider_class.prefetch("/" => @mount)
            @mount.provider.property_hash[:ensure].should == :present
        end

        it "should determine that the root fs is mounted" do
            @provider_class.prefetch("/" => @mount)
            @mount.provider.should be_mounted
        end
    end

    describe provider_class, " when mounting and unmounting" do
        include ParsedMountTesting

        it "should call the 'mount' command to mount the filesystem"

        it "should call the 'unmount' command to unmount the filesystem"

        it "should specify the filesystem when remounting a filesystem"
    end
end
