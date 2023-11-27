require 'spec_helper'

describe Puppet::Type.type(:package).provider(:appdmg) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'foo', :provider => :appdmg) }
  let(:provider) { described_class.new(resource) }

  describe "when installing an appdmg" do
    let(:fake_mountpoint) { "/tmp/dmg.foo" }
    let(:fake_hdiutil_plist) { {"system-entities" => [{"mount-point" => fake_mountpoint}]} }

    before do
      fh = double('filehandle', path: '/tmp/foo')
      resource[:source] = "foo.dmg"
      allow(File).to receive(:open).and_yield(fh)
      allow(Dir).to receive(:mktmpdir).and_return("/tmp/testtmp123")
      allow(FileUtils).to receive(:remove_entry_secure)
    end

    describe "from a remote source" do
      let(:tmpdir) { "/tmp/good123" }

      before :each do
        resource[:source] = "http://fake.puppetlabs.com/foo.dmg"
      end

      it "should call tmpdir and use the returned directory" do
        expect(Dir).to receive(:mktmpdir).and_return(tmpdir)
        allow(Dir).to receive(:entries).and_return(["foo.app"])
        expect(described_class).to receive(:curl) do |*args|
          expect(args[0]).to eq("-o")
          expect(args[1]).to include(tmpdir)
          expect(args).not_to include("-k")
        end
        allow(described_class).to receive(:hdiutil).and_return('a plist')
        expect(Puppet::Util::Plist).to receive(:parse_plist).with('a plist').and_return(fake_hdiutil_plist)
        expect(described_class).to receive(:installapp)

        provider.install
      end
    end
  end
end
