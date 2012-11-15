#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:appdmg) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'foo', :provider => :appdmg) }
  let(:provider) { described_class.new(resource) }

  describe "when installing an appdmg" do
    let(:fake_mountpoint) { "/tmp/dmg.foo" }
    let(:empty_hdiutil_plist) { Plist::Emit.dump({}) }
    let(:fake_hdiutil_plist) { Plist::Emit.dump({"system-entities" => [{"mount-point" => fake_mountpoint}]}) }

    before do
      fh = mock 'filehandle'
      fh.stubs(:path).yields "/tmp/foo"
      resource[:source] = "foo.dmg"
      described_class.stubs(:open).yields fh
      Dir.stubs(:mktmpdir).returns "/tmp/testtmp123"
      FileUtils.stubs(:remove_entry_secure)
    end

    describe "from a remote source" do
      let(:tmpdir) { "/tmp/good123" }

      before :each do
        resource[:source] = "http://fake.puppetlabs.com/foo.dmg"
      end

      it "should call tmpdir and use the returned directory" do
        Dir.expects(:mktmpdir).returns tmpdir
        Dir.stubs(:entries).returns ["foo.app"]
        described_class.expects(:curl).with do |*args|
          args[0] == "-o" and args[1].include? tmpdir
        end
        described_class.stubs(:hdiutil).returns fake_hdiutil_plist
        described_class.expects(:installapp)

        provider.install
      end
    end
  end
end
