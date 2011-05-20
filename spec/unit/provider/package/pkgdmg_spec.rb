#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:pkgdmg)

describe provider do
  before do
    @resource = stub 'resource', :[] => "dummypkgdmg"
    @provider = provider.new(@resource)

    @fakemountpoint   = "/tmp/dmg.foo"
    @fakepkgfile      = "/tmp/test.pkg"
    @fakehdiutilinfo  = {"system-entities" => [{"mount-point" => @fakemountpoint}] }
    @fakehdiutilplist = Plist::Emit.dump(@fakehdiutilinfo)

    @hdiutilmountargs = ["mount", "-plist", "-nobrowse", "-readonly",
      "-noidme", "-mountrandom", "/tmp"]
  end

  it "should not be versionable" do
    provider.versionable?.should be_false
  end

  it "should not be uninstallable" do
    provider.uninstallable?.should be_false
  end

  describe "when installing it should fail when" do
    it "no source is specified" do
      @resource.stubs(:[]).with(:source).returns nil
      lambda { @provider.install }.should raise_error(Puppet::Error)
    end

    it "no name is specified" do
      @resource.stubs(:[]).with(:name).returns nil
      lambda { @provider.install }.should raise_error(Puppet::Error)
    end

    it "the source does not end in .dmg or .pkg" do
      @resource.stubs(:[]).with(:source).returns "notendingindotdmgorpkg"
      lambda { @provider.install }.should raise_error(Puppet::Error)
    end

    it "a disk image with no system entities is mounted" do
      @provider.stubs(:[]).with(:hdiutil).returns ""
      lambda { @provider.install }.should raise_error(Puppet::Error)
    end
  end

  # These tests shouldn't be this messy. The pkgdmg provider needs work...
  describe "when installing a pkgdmg" do
    before do
      fh = mock 'filehandle'
      fh.stubs(:path).yields "/tmp/foo"
      @resource.stubs(:[]).with(:source).returns "foo.dmg"
      File.stubs(:open).yields fh
    end

    it "should call hdiutil to mount and eject the disk image" do
      Dir.stubs(:entries).returns []
      @provider.class.expects(:hdiutil).with("eject", @fakemountpoint).returns 0
      @provider.class.expects(:hdiutil).with("mount", "-plist", "-nobrowse", "-readonly", "-noidme", "-mountrandom", "/tmp", nil).returns @fakehdiutilplist
      @provider.install
    end

    it "should call installpkg if a pkg/mpkg is found on the dmg" do
      Dir.stubs(:entries).returns ["foo.pkg"]
      @provider.class.stubs(:hdiutil).returns @fakehdiutilplist
      @provider.class.expects(:installpkg).with("#{@fakemountpoint}/foo.pkg", @resource[:name], "foo.dmg").returns ""
      @provider.install
    end
  end

  describe "when installing flat pkg file" do
    it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
      @resource.stubs(:[]).with(:source).returns "/tmp/test.pkg"
      @resource.stubs(:[]).with(:name).returns "testpkg"
        @provider.class.expects(:installpkgdmg).with("#{@fakepkgfile}", "testpkg").returns ""
        @provider.install
        end
  end

end
