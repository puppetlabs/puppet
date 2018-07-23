#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/mount'

describe Puppet::Provider::Mount do
  before :each do
    @mounter = Object.new
    @mounter.extend(Puppet::Provider::Mount)

    @name = "/"

    @resource = stub 'resource'
    @resource.stubs(:[]).with(:name).returns(@name)

    @mounter.stubs(:resource).returns(@resource)
  end

  describe Puppet::Provider::Mount, " when mounting" do

    before :each do
      @mounter.stubs(:get).with(:ensure).returns(:mounted)
    end

    it "should use the 'mountcmd' method to mount" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd)

      @mounter.mount
    end

    it "should add the options following '-o' on MacOS if they exist and are not set to :absent" do
      Facter.expects(:value).with(:kernel).returns 'Darwin'
      @mounter.stubs(:options).returns("ro")
      @mounter.expects(:mountcmd).with '-o', 'ro', '/'

      @mounter.mount
    end

    it "should not explicitly pass mount options on systems other than MacOS" do
      Facter.expects(:value).with(:kernel).returns 'HP-UX'
      @mounter.stubs(:options).returns("ro")
      @mounter.expects(:mountcmd).with '/'

      @mounter.mount
    end

    it "should specify the filesystem name to the mount command" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd).with { |*ary| ary[-1] == @name }

      @mounter.mount
    end

    it "should update the :ensure state to :mounted if it was :unmounted before" do
      @mounter.expects(:mountcmd)
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:get).with(:ensure).returns(:unmounted)
      @mounter.expects(:set).with(:ensure => :mounted)
      @mounter.mount
    end

    it "should update the :ensure state to :ghost if it was :absent before" do
      @mounter.expects(:mountcmd)
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:get).with(:ensure).returns(:absent)
      @mounter.expects(:set).with(:ensure => :ghost)
      @mounter.mount
    end

  end

  describe Puppet::Provider::Mount, " when remounting" do

    context "if the resource supports remounting" do
      context "given explicit options on AIX" do
        it "should combine the options with 'remount'" do
          @mounter.stubs(:info)
          @mounter.stubs(:options).returns('ro')
          @resource.stubs(:[]).with(:remounts).returns(:true)
          Facter.expects(:value).with(:operatingsystem).returns 'AIX'
          @mounter.expects(:mountcmd).with("-o", "ro,remount", @name)
          @mounter.remount
        end
      end

      it "should use '-o remount'" do
        @mounter.stubs(:info)
        @resource.stubs(:[]).with(:remounts).returns(:true)
        @mounter.expects(:mountcmd).with("-o", "remount", @name)
        @mounter.remount
      end
    end

    it "should mount with '-o update' on OpenBSD" do
      @mounter.stubs(:info)
      @mounter.stubs(:options)
      @resource.stubs(:[]).with(:remounts).returns(false)
      Facter.expects(:value).with(:operatingsystem).returns 'OpenBSD'
      @mounter.expects(:mountcmd).with("-o", "update", @name)
      @mounter.remount
    end

    it "should unmount and mount if the resource does not specify it supports remounting" do
      @mounter.stubs(:info)
      @mounter.stubs(:options)
      @resource.stubs(:[]).with(:remounts).returns(false)
      Facter.expects(:value).with(:operatingsystem).returns 'AIX'
      @mounter.expects(:mount)
      @mounter.expects(:unmount)
      @mounter.remount
    end

    it "should log that it is remounting" do
      @resource.stubs(:[]).with(:remounts).returns(:true)
      @mounter.stubs(:mountcmd)
      @mounter.expects(:info).with("Remounting")
      @mounter.remount
    end
  end

  describe Puppet::Provider::Mount, " when unmounting" do

    before :each do
      @mounter.stubs(:get).with(:ensure).returns(:unmounted)
    end

    it "should call the :umount command with the resource name" do
      @mounter.expects(:umount).with(@name)
      @mounter.unmount
    end

    it "should update the :ensure state to :absent if it was :ghost before" do
      @mounter.expects(:umount).with(@name).returns true
      @mounter.expects(:get).with(:ensure).returns(:ghost)
      @mounter.expects(:set).with(:ensure => :absent)
      @mounter.unmount
    end

    it "should update the :ensure state to :unmounted if it was :mounted before" do
      @mounter.expects(:umount).with(@name).returns true
      @mounter.expects(:get).with(:ensure).returns(:mounted)
      @mounter.expects(:set).with(:ensure => :unmounted)
      @mounter.unmount
    end

  end

  describe Puppet::Provider::Mount, " when determining if it is mounted" do

    it "should query the property_hash" do
      @mounter.expects(:get).with(:ensure).returns(:mounted)
      @mounter.mounted?
    end

    it "should return true if prefetched value is :mounted" do
      @mounter.stubs(:get).with(:ensure).returns(:mounted)
      @mounter.mounted? == true
    end

    it "should return true if prefetched value is :ghost" do
      @mounter.stubs(:get).with(:ensure).returns(:ghost)
      @mounter.mounted? == true
    end

    it "should return false if prefetched value is :absent" do
      @mounter.stubs(:get).with(:ensure).returns(:absent)
      @mounter.mounted? == false
    end

    it "should return false if prefetched value is :unmounted" do
      @mounter.stubs(:get).with(:ensure).returns(:unmounted)
      @mounter.mounted? == false
    end

  end

end
