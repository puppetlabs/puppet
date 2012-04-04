#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkgdmg) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'foo', :provider => :pkgdmg) }
  let(:provider) { described_class.new(resource) }

  it { should_not be_versionable }
  it { should_not be_uninstallable }

  describe "when installing it should fail when" do
    before :each do
      Puppet::Util.expects(:execute).never
    end

    it "no source is specified" do
      expect { provider.install }.should raise_error(Puppet::Error, /must specify a package source/)
    end

    it "the source does not end in .dmg or .pkg" do
      resource[:source] = "bar"
      expect { provider.install }.should raise_error(Puppet::Error, /must specify a source string ending in .*dmg.*pkg/)
    end
  end

  # These tests shouldn't be this messy. The pkgdmg provider needs work...
  describe "when installing a pkgdmg" do
    let(:fake_mountpoint) { "/tmp/dmg.foo" }
    let(:empty_hdiutil_plist) { Plist::Emit.dump({}) }
    let(:fake_hdiutil_plist) { Plist::Emit.dump({"system-entities" => [{"mount-point" => fake_mountpoint}]}) }

    before do
      fh = mock 'filehandle'
      fh.stubs(:path).yields "/tmp/foo"
      resource[:source] = "foo.dmg"
      File.stubs(:open).yields fh
      Dir.stubs(:mktmpdir).returns "/tmp/testtmp123"
      FileUtils.stubs(:remove_entry_secure)
    end

    it "should fail when a disk image with no system entities is mounted" do
      described_class.stubs(:hdiutil).returns(empty_hdiutil_plist)
      expect { provider.install }.should raise_error(Puppet::Error, /No disk entities/)
    end

    it "should call hdiutil to mount and eject the disk image" do
      Dir.stubs(:entries).returns []
      provider.class.expects(:hdiutil).with("eject", fake_mountpoint).returns 0
      provider.class.expects(:hdiutil).with("mount", "-plist", "-nobrowse", "-readonly", "-noidme", "-mountrandom", "/tmp", nil).returns fake_hdiutil_plist
      provider.install
    end

    it "should call installpkg if a pkg/mpkg is found on the dmg" do
      Dir.stubs(:entries).returns ["foo.pkg"]
      provider.class.stubs(:hdiutil).returns fake_hdiutil_plist
      provider.class.expects(:installpkg).with("#{fake_mountpoint}/foo.pkg", resource[:name], "foo.dmg").returns ""
      provider.install
    end

    describe "from a remote source" do
      let(:tmpdir) { "/tmp/good123" }

      before :each do
        resource[:source] = "http://fake.puppetlabs.com/foo.dmg"
      end

      it "should call tmpdir and use the returned directory" do
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.pkg"]
        described_class.expects(:curl).with do |*args|
          args[0] == "-o" and args[1].include? tmpdir
        end
        described_class.stubs(:hdiutil).returns fake_hdiutil_plist
        described_class.expects(:installpkg)

        provider.install
      end
    end
  end

  describe "when installing flat pkg file" do
    it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
      resource[:source] = "/tmp/test.pkg"
      resource[:name] = "testpkg"
      provider.class.expects(:installpkgdmg).with("/tmp/test.pkg", "testpkg").returns ""
      provider.install
    end
  end
end
