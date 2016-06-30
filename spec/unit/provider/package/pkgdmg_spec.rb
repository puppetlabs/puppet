#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkgdmg) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'foo', :provider => :pkgdmg) }
  let(:provider) { described_class.new(resource) }

  it { is_expected.not_to be_versionable }
  it { is_expected.not_to be_uninstallable }

  describe "when installing it should fail when" do
    before :each do
      Puppet::Util.expects(:execute).never
    end

    it "no source is specified" do
      expect { provider.install }.to raise_error(Puppet::Error, /must specify a package source/)
    end

    it "the source does not end in .dmg or .pkg" do
      resource[:source] = "bar"
      expect { provider.install }.to raise_error(Puppet::Error, /must specify a source string ending in .*dmg.*pkg/)
    end
  end

  # These tests shouldn't be this messy. The pkgdmg provider needs work...
  describe "when installing a pkgdmg" do
    let(:fake_mountpoint) { "/tmp/dmg.foo" }
    let(:fake_hdiutil_plist) { {"system-entities" => [{"mount-point" => fake_mountpoint}]} }

    before do
      fh = mock 'filehandle'
      fh.stubs(:path).yields "/tmp/foo"
      resource[:source] = "foo.dmg"
      File.stubs(:open).yields fh
      Dir.stubs(:mktmpdir).returns "/tmp/testtmp123"
      FileUtils.stubs(:remove_entry_secure)
    end

    it "should fail when a disk image with no system entities is mounted" do
      described_class.stubs(:hdiutil).returns 'empty plist'
      Puppet::Util::Plist.expects(:parse_plist).with('empty plist').returns({})
      expect { provider.install }.to raise_error(Puppet::Error, /No disk entities/)
    end

    it "should call hdiutil to mount and eject the disk image" do
      Dir.stubs(:entries).returns []
      provider.class.expects(:hdiutil).with("eject", fake_mountpoint).returns 0
      provider.class.expects(:hdiutil).with("mount", "-plist", "-nobrowse", "-readonly", "-noidme", "-mountrandom", "/tmp", nil).returns 'a plist'
      Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
      provider.install
    end

    it "should call installpkg if a pkg/mpkg is found on the dmg" do
      Dir.stubs(:entries).returns ["foo.pkg"]
      provider.class.stubs(:hdiutil).returns 'a plist'
      Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
      provider.class.expects(:installpkg).with("#{fake_mountpoint}/foo.pkg", resource[:name], "foo.dmg").returns ""
      provider.install
    end

    describe "from a remote source" do
      let(:tmpdir) { "/tmp/good123" }

      before :each do
        resource[:source] = "http://fake.puppetlabs.com/foo.dmg"
      end

      it "should call tmpdir and then call curl with that directory" do
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.pkg"]
        described_class.expects(:curl).with do |*args|
          args[0] == "-o" && args[1].include?(tmpdir) && args.include?("--fail") && ! args.include?("-k")
        end
        described_class.stubs(:hdiutil).returns 'a plist'
        Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
        described_class.expects(:installpkg)

        provider.install
      end

      it "should use an http proxy host and port if specified" do
        Puppet::Util::HttpProxy.expects(:no_proxy?).returns false
        Puppet::Util::HttpProxy.expects(:http_proxy_host).returns 'some_host'
        Puppet::Util::HttpProxy.expects(:http_proxy_port).returns 'some_port'
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.pkg"]
        described_class.expects(:curl).with do |*args|
          expect(args).to be_include 'some_host:some_port'
          expect(args).to be_include '--proxy'
        end
        described_class.stubs(:hdiutil).returns 'a plist'
        Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
        described_class.expects(:installpkg)

        provider.install
      end

      it "should use an http proxy host only if specified" do
        Puppet::Util::HttpProxy.expects(:no_proxy?).returns false
        Puppet::Util::HttpProxy.expects(:http_proxy_host).returns 'some_host'
        Puppet::Util::HttpProxy.expects(:http_proxy_port).returns nil
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.pkg"]
        described_class.expects(:curl).with do |*args|
          expect(args).to be_include 'some_host'
          expect(args).to be_include '--proxy'
        end
        described_class.stubs(:hdiutil).returns 'a plist'
        Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
        described_class.expects(:installpkg)

        provider.install
      end

      it "should not use the configured proxy if no_proxy contains a match for the destination" do
        Puppet::Util::HttpProxy.expects(:no_proxy?).returns true
        Puppet::Util::HttpProxy.expects(:http_proxy_host).never
        Puppet::Util::HttpProxy.expects(:http_proxy_port).never
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.pkg"]
        described_class.expects(:curl).with do |*args|
          expect(args).not_to be_include 'some_host:some_port'
          expect(args).not_to be_include '--proxy'
          true
        end
        described_class.stubs(:hdiutil).returns 'a plist'
        Puppet::Util::Plist.expects(:parse_plist).with('a plist').returns fake_hdiutil_plist
        described_class.expects(:installpkg)

        provider.install
      end
    end
  end

  describe "when installing flat pkg file" do
    describe "with a local source" do
      it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
        resource[:source] = "/tmp/test.pkg"
        resource[:name] = "testpkg"
        provider.class.expects(:installpkgdmg).with("/tmp/test.pkg", "testpkg").returns ""
        provider.install
      end
    end

    describe "with a remote source" do
      let(:remote_source) { 'http://fake.puppetlabs.com/test.pkg' }
      let(:tmpdir) { '/path/to/tmpdir' }
      let(:tmpfile) { File.join(tmpdir, 'testpkg.pkg') }

      before do
        resource[:name]   = 'testpkg'
        resource[:source] = remote_source

        Dir.stubs(:mktmpdir).returns tmpdir
      end

      it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
        described_class.expects(:curl).with do |*args|
          expect(args).to be_include tmpfile
          expect(args).to be_include remote_source
        end
        provider.class.expects(:installpkg).with(tmpfile, 'testpkg', remote_source)
        provider.install
      end
    end
  end
end
