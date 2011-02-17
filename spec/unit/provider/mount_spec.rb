#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet_spec/files'
require 'puppet/provider/mount'

describe Puppet::Provider::Mount do
  include PuppetSpec::Files

  before :each do
    @name = "/"

    @resource = Puppet::Type.type(:mount).new(
      :name => '/',
      :device => '/dev/sda1',
      :target => tmpfile("mount_provider")
    )

    @mounter = Puppet::Type.type(:mount).defaultprovider().new(@resource)
  end

  describe "when calling mount!" do
    it "should use the 'mountcmd' method to mount" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd)

      @mounter.mount!
    end

    it "should flush before mounting if a flush method exists" do
      @mounter.meta_def(:flush) { }
      @mounter.expects(:flush)
      @mounter.stubs(:mountcmd)
      @mounter.stubs(:options).returns(nil)

      @mounter.mount!
    end

    it "should add the options following '-o' if they exist and are not set to :absent" do
      @mounter.stubs(:options).returns("ro")
      @mounter.expects(:mountcmd).with { |*ary| ary[0] == "-o" and ary[1] == "ro" }

      @mounter.mount!
    end

    it "should specify the filesystem name to the mount command" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd).with { |*ary| ary[-1] == @name }

      @mounter.mount!
    end
  end

  describe "when remounting" do
    it "should use '-o remount' if the resource specifies it supports remounting" do
      @mounter.stubs(:info)
      @resource[:remounts] = true
      @mounter.expects(:mountcmd).with("-o", "remount", @name)
      @mounter.remount
    end

    it "should unmount and mount if the resource does not specify it supports remounting" do
      @mounter.stubs(:info)
      @resource[:remounts] = false
      @mounter.expects(:unmount)
      @mounter.expects(:mount)
      @mounter.remount
    end

    it "should log that it is remounting" do
      @resource[:remounts] = true
      @mounter.stubs(:mountcmd)
      @mounter.expects(:info).with("Remounting")
      @mounter.remount
    end
  end

  describe "when unmounting" do
    it "should call the :umount command with the resource name" do
      @mounter.expects(:umount).with(@name)
      @mounter.unmount
    end
  end

  %w{Darwin Solaris HP-UX AIX Other}.each do |platform|
    describe "on #{platform}" do
      before :each do
        case platform
        when 'Darwin'
          mount_fixture = 'mount-output.darwin.txt'
          @mount_device = '/dev/disk0s3'
          @mount_point = '/usr'
        when 'Solaris'
          mount_fixture = 'mount-output.solaris.txt'
          @mount_device = 'swap'
          @mount_point = '/tmp'
        when 'HP-UX'
          mount_fixture = 'mount-output.hp-ux.txt'
          @mount_device = 'swap'
          @mount_point = '/tmp'
        when 'AIX'
          mount_fixture = 'mount-output.aix.txt'
          @mount_device = '/dev/hd2'
          @mount_point = '/usr'
        when 'Other'
          mount_fixture = 'mount-output.other.txt'
          @mount_device = '/dev/sda2'
          @mount_point = '/usr'
        end
        @mount_data = File.read(File.join(File.dirname(__FILE__), '..', '..', 'fixtures', 'unit', 'provider', 'mount', mount_fixture))
        Facter.stubs(:value).with("operatingsystem").returns(platform)
      end

      describe "when the correct thing is mounted" do
        before :each do
          @mounter.expects(:mountcmd).returns(@mount_data)
          @resource.stubs(:[]).with(:name).returns(@mount_point)
          @resource.stubs(:[]).with(:device).returns(@mount_device)
        end

        it "should say anything_mounted?" do
          @mounter.should be_anything_mounted
        end

        it "should say correctly_mounted?" do
          @mounter.should be_correctly_mounted
        end
      end

      describe "when the wrong thing is mounted" do
        before :each do
          @mounter.expects(:mountcmd).returns(@mount_data)
          @resource.stubs(:[]).with(:name).returns(@mount_point)
          @resource.stubs(:[]).with(:device).returns('/dev/bogus/thing')
        end

        it "should say anything_mounted?" do
          @mounter.should be_anything_mounted
        end

        it "should not say correctly_mounted?" do
          @mounter.should_not be_correctly_mounted
        end
      end

      describe "when nothing is mounted" do
        before :each do
          @mounter.expects(:mountcmd).returns(@mount_data)
          @resource.stubs(:[]).with(:name).returns('/bogus/location')
          @resource.stubs(:[]).with(:device).returns(@mount_device)
        end

        it "should not say anything_mounted?" do
          @mounter.should_not be_anything_mounted
        end

        it "should not say correctly_mounted?" do
          @mounter.should_not be_correctly_mounted
        end
      end
    end
  end

  describe "when mounting a device" do
    it "should not mount! or unmount anything when the correct device is mounted" do
      @mounter.stubs(:correctly_mounted?).returns(true)

      @mounter.expects(:anything_mounted?).never
      @mounter.expects(:create).once
      @mounter.expects(:mount!).never
      @mounter.expects(:unmount).never
      FileUtils.expects(:mkdir_p).never

      @mounter.mount
    end

    it "should mount the device when nothing is mounted at the desired point" do
      @mounter.stubs(:correctly_mounted?).returns(false)
      @mounter.stubs(:anything_mounted?).returns(false)

      @mounter.expects(:create).once
      @mounter.expects(:mount!).once
      @mounter.expects(:unmount).never
      FileUtils.expects(:mkdir_p).never

      @mounter.mount
    end

    it "should unmount the incorrect device and mount the correct device" do
      @mounter.stubs(:correctly_mounted?).returns(false)
      @mounter.stubs(:anything_mounted?).returns(true)

      @mounter.expects(:create).once
      @mounter.expects(:mount!).once
      @mounter.expects(:unmount).once
      FileUtils.expects(:mkdir_p).with(@name).returns(true)

      @mounter.mount
    end
  end
end
