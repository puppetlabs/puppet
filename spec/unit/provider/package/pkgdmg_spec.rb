require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkgdmg) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'foo', :provider => :pkgdmg) }
  let(:provider) { described_class.new(resource) }

  it { is_expected.not_to be_versionable }
  it { is_expected.not_to be_uninstallable }

  describe "when installing it should fail when" do
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
      fh = double('filehandle')
      allow(fh).to receive(:path).and_return("/tmp/foo")
      resource[:source] = "foo.dmg"
      allow(File).to receive(:open).and_yield(fh)
      allow(Dir).to receive(:mktmpdir).and_return("/tmp/testtmp123")
      allow(FileUtils).to receive(:remove_entry_secure)
    end

    it "should fail when a disk image with no system entities is mounted" do
      allow(described_class).to receive(:hdiutil).and_return('empty plist')
      expect(Puppet::Util::Plist).to receive(:parse_plist).with('empty plist').and_return({})
      expect { provider.install }.to raise_error(Puppet::Error, /No disk entities/)
    end

    it "should call hdiutil to mount and eject the disk image" do
      allow(Dir).to receive(:entries).and_return([])
      expect(provider.class).to receive(:hdiutil).with("eject", fake_mountpoint).and_return(0)
      expect(provider.class).to receive(:hdiutil).with("mount", "-plist", "-nobrowse", "-readonly", "-mountrandom", "/tmp", '/tmp/foo').and_return('a plist')
      expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
      provider.install
    end

    it "should call installpkg if a pkg/mpkg is found on the dmg" do
      allow(Dir).to receive(:entries).and_return(["foo.pkg"])
      allow(provider.class).to receive(:hdiutil).and_return('a plist')
      expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
      expect(provider.class).to receive(:installpkg).with("#{fake_mountpoint}/foo.pkg", resource[:name], "foo.dmg").and_return("")
      provider.install
    end

    describe "from a remote source" do
      let(:tmpdir) { "/tmp/good123" }

      before :each do
        resource[:source] = "http://fake.puppetlabs.com/foo.dmg"
      end

      it "should call tmpdir and then call curl with that directory" do
        expect(Dir).to receive(:mktmpdir).and_return(tmpdir)
        allow(Dir).to receive(:entries).and_return(["foo.pkg"])
        expect(described_class).to receive(:curl) do |*args|
          expect(args[0]).to eq("-o")
          expect(args[1]).to include(tmpdir)
          expect(args).to include("--fail")
          expect(args).not_to include("-k")
        end
        allow(described_class).to receive(:hdiutil).and_return('a plist')
        expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
        expect(described_class).to receive(:installpkg)

        provider.install
      end

      it "should use an http proxy host and port if specified" do
        expect(Puppet::Util::HttpProxy).to receive(:no_proxy?).and_return(false)
        expect(Puppet::Util::HttpProxy).to receive(:http_proxy_host).and_return('some_host')
        expect(Puppet::Util::HttpProxy).to receive(:http_proxy_port).and_return('some_port')
        expect(Dir).to receive(:mktmpdir).and_return(tmpdir)
        allow(Dir).to receive(:entries).and_return(["foo.pkg"])
        expect(described_class).to receive(:curl) do |*args|
          expect(args).to include('some_host:some_port')
          expect(args).to include('--proxy')
        end
        allow(described_class).to receive(:hdiutil).and_return('a plist')
        expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
        expect(described_class).to receive(:installpkg)

        provider.install
      end

      it "should use an http proxy host only if specified" do
        expect(Puppet::Util::HttpProxy).to receive(:no_proxy?).and_return(false)
        expect(Puppet::Util::HttpProxy).to receive(:http_proxy_host).and_return('some_host')
        expect(Puppet::Util::HttpProxy).to receive(:http_proxy_port).and_return(nil)
        expect(Dir).to receive(:mktmpdir).and_return(tmpdir)
        allow(Dir).to receive(:entries).and_return(["foo.pkg"])
        expect(described_class).to receive(:curl) do |*args|
          expect(args).to include('some_host')
          expect(args).to include('--proxy')
        end
        allow(described_class).to receive(:hdiutil).and_return('a plist')
        expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
        expect(described_class).to receive(:installpkg)

        provider.install
      end

      it "should not use the configured proxy if no_proxy contains a match for the destination" do
        expect(Puppet::Util::HttpProxy).to receive(:no_proxy?).and_return(true)
        expect(Puppet::Util::HttpProxy).not_to receive(:http_proxy_host)
        expect(Puppet::Util::HttpProxy).not_to receive(:http_proxy_port)
        expect(Dir).to receive(:mktmpdir).and_return(tmpdir)
        allow(Dir).to receive(:entries).and_return(["foo.pkg"])
        expect(described_class).to receive(:curl) do |*args|
          expect(args).not_to include('some_host:some_port')
          expect(args).not_to include('--proxy')
          true
        end
        allow(described_class).to receive(:hdiutil).and_return('a plist')
        expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
        expect(described_class).to receive(:installpkg)

        provider.install
      end
    end
  end

  describe "when installing flat pkg file" do
    describe "with a local source" do
      it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
        resource[:source] = "/tmp/test.pkg"
        resource[:name] = "testpkg"
        expect(provider.class).to receive(:installpkgdmg).with("/tmp/test.pkg", "testpkg").and_return("")
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

        allow(Dir).to receive(:mktmpdir).and_return(tmpdir)
      end

      it "should call installpkg if a flat pkg file is found instead of a .dmg image" do
        expect(described_class).to receive(:curl) do |*args|
          expect(args).to include(tmpfile)
          expect(args).to include(remote_source)
        end
        expect(provider.class).to receive(:installpkg).with(tmpfile, 'testpkg', remote_source)
        provider.install
      end
    end
  end
end
