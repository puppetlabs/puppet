#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

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

    it "should use the 'mountcmd' method to mount" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd)

      @mounter.mount
    end

    it "should flush before mounting if a flush method exists" do
      @mounter.meta_def(:flush) { }
      @mounter.expects(:flush)
      @mounter.stubs(:mountcmd)
      @mounter.stubs(:options).returns(nil)

      @mounter.mount
    end

    it "should add the options following '-o' if they exist and are not set to :absent" do
      @mounter.stubs(:options).returns("ro")
      @mounter.expects(:mountcmd).with { |*ary| ary[0] == "-o" and ary[1] == "ro" }

      @mounter.mount
    end

    it "should specify the filesystem name to the mount command" do
      @mounter.stubs(:options).returns(nil)
      @mounter.expects(:mountcmd).with { |*ary| ary[-1] == @name }

      @mounter.mount
    end
  end

  describe Puppet::Provider::Mount, " when remounting" do

    it "should use '-o remount' if the resource specifies it supports remounting" do
      @mounter.stubs(:info)
      @resource.stubs(:[]).with(:remounts).returns(:true)
      @mounter.expects(:mountcmd).with("-o", "remount", @name)
      @mounter.remount
    end

    it "should unmount and mount if the resource does not specify it supports remounting" do
      @mounter.stubs(:info)
      @resource.stubs(:[]).with(:remounts).returns(false)
      @mounter.expects(:unmount)
      @mounter.expects(:mount)
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

    it "should call the :umount command with the resource name" do
      @mounter.expects(:umount).with(@name)
      @mounter.unmount
    end
  end

  describe Puppet::Provider::Mount, " when determining if it is mounted" do

    it "should parse the results of running the mount command with no arguments" do
      Facter.stubs(:value).returns("whatever")
      @mounter.expects(:mountcmd).returns("")

      @mounter.mounted?
    end

    it "should match ' on /private/var/automount<name>' if the operating system is Darwin" do
      Facter.stubs(:value).with("operatingsystem").returns("Darwin")
      @mounter.expects(:mountcmd).returns("/dev/whatever on /private/var/automount/\ndevfs on /dev")

      @mounter.should be_mounted
    end

    it "should match ' on <name>' if the operating system is Darwin" do
      Facter.stubs(:value).with("operatingsystem").returns("Darwin")
      @mounter.expects(:mountcmd).returns("/dev/disk03 on / (local, journaled)\ndevfs on /dev")

      @mounter.should be_mounted
    end

    it "should match '^<name> on' if the operating system is Solaris" do
      Facter.stubs(:value).with("operatingsystem").returns("Solaris")
      @mounter.expects(:mountcmd).returns("/ on /dev/dsk/whatever\n/var on /dev/dsk/other")

      @mounter.should be_mounted
    end

    it "should match '^<name> on' if the operating system is HP-UX" do
      Facter.stubs(:value).with("operatingsystem").returns("HP-UX")
      @mounter.expects(:mountcmd).returns("/ on /dev/dsk/whatever\n/var on /dev/dsk/other")

      @mounter.should be_mounted
    end

    it "should match ' on <name>' if the operating system is not Darwin, Solaris, or HP-UX" do
      Facter.stubs(:value).with("operatingsystem").returns("Debian")
      @mounter.expects(:mountcmd).returns("/dev/dsk/whatever on / and stuff\n/dev/other/disk on /var and stuff")

      @mounter.should be_mounted
    end

    it "should not be considered mounted if it did not match the mount output" do
      Facter.stubs(:value).with("operatingsystem").returns("Debian")
      @mounter.expects(:mountcmd).returns("/dev/dsk/whatever on /something/else and stuff\n/dev/other/disk on /var and stuff")

      @mounter.should_not be_mounted
    end
  end
end
