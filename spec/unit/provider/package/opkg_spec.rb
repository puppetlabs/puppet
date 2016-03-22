#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:opkg) do

  let(:resource) do
    Puppet::Type.type(:package).new(:name => 'package')
  end

  let(:provider) { described_class.new(resource) }

  before do
    Puppet::Util::Execution.stubs(:execute).never
    Puppet::Util.stubs(:which).with("opkg").returns("/bin/opkg")
    provider.stubs(:package_lists).returns ['.', '..', 'packages']
  end

  describe "when installing" do
    before do
      provider.stubs(:query).returns({ :ensure => '1.0' })
    end

    context "when the package list is absent" do
      before do
        provider.stubs(:package_lists).returns ['.', '..']  #empty, no package list
      end

      it "fetches the package list when installing" do
        provider.expects(:opkg).with('update')
        provider.expects(:opkg).with("--force-overwrite", "install", resource[:name])

        provider.install
      end
    end

    context "when the package list is present" do
      before do
        provider.stubs(:package_lists).returns ['.', '..', 'lists']  # With a pre-downloaded package list
      end

      it "fetches the package list when installing" do
        provider.expects(:opkg).with('update').never
        provider.expects(:opkg).with("--force-overwrite", "install", resource[:name])

        provider.install
      end
    end

    it "should call opkg install" do
      Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "--force-overwrite", "install", resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
      provider.install
    end

    context "when :source is specified" do
      context "works on valid urls" do
        %w{
          /some/package/file
          http://some.package.in/the/air
          ftp://some.package.in/the/air
        }.each do |source|
          it "should install #{source} directly" do
            resource[:source] = source
            Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "--force-overwrite", "install", resource[:source]], {:failonfail => true, :combine => true, :custom_environment => {}})
            provider.install
          end
        end
      end

      context "as a file:// URL" do
        before do
          @package_file = "file:///some/package/file"
          @actual_file_path = "/some/package/file"
          resource[:source] = @package_file
        end

        it "should install from the path segment of the URL" do
          Puppet::Util::Execution.expects(:execute).returns("")
          provider.install
        end
      end

      context "with invalid URL for opkg" do
        before do
          # Emulate the `opkg` command returning a non-zero exit value
          Puppet::Util::Execution.stubs(:execute).raises Puppet::ExecutionFailure, 'oops'
        end

        context "puppet://server/whatever" do
          before do
            resource[:source] = "puppet://server/whatever"
          end

          it "should fail" do
            expect { provider.install }.to raise_error Puppet::ExecutionFailure
          end
        end

        context "as a malformed URL" do
          before do
            resource[:source] = "blah://"
          end

          it "should fail" do
            expect { provider.install }.to raise_error Puppet::ExecutionFailure
          end
        end
      end
    end # end when source is specified
  end # end when installing

  describe "when updating" do
    it "should call install" do
      provider.expects(:install).returns("install return value")
      expect(provider.update).to eq("install return value")
    end
  end

  describe "when uninstalling" do
    it "should run opkg remove bla" do
      Puppet::Util::Execution.expects(:execute).with(["/bin/opkg", "remove", resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
      provider.uninstall
    end
  end

  describe "when querying" do

    describe "self.instances" do
      let (:packages) do
        <<-OPKG_OUTPUT
dropbear - 2011.54-2
kernel - 3.3.8-1-ba5cdb2523b4fc7722698b4a7ece6702
uhttpd - 2012-10-30-e57bf6d8bfa465a50eea2c30269acdfe751a46fd
OPKG_OUTPUT
      end
      it "returns an array of packages" do
        Puppet::Util.stubs(:which).with("opkg").returns("/bin/opkg")
        described_class.stubs(:which).with("opkg").returns("/bin/opkg")
        described_class.expects(:execpipe).with("/bin/opkg list-installed").yields(packages)

        installed_packages = described_class.instances
        expect(installed_packages.length).to eq(3)

        expect(installed_packages[0].properties).to eq(
          {
            :provider => :opkg,
            :name => "dropbear",
            :ensure => "2011.54-2"
          }
        )
        expect(installed_packages[1].properties).to eq(
          {
            :provider => :opkg,
            :name => "kernel",
            :ensure => "3.3.8-1-ba5cdb2523b4fc7722698b4a7ece6702"
          }
        )
        expect(installed_packages[2].properties).to eq(
          {
            :provider => :opkg,
            :name => "uhttpd",
            :ensure => "2012-10-30-e57bf6d8bfa465a50eea2c30269acdfe751a46fd"
          }
        )
      end
    end

    it "should return a nil if the package isn't found" do
      Puppet::Util::Execution.expects(:execute).returns("")
      expect(provider.query).to be_nil
    end

    it "should return a hash indicating that the package is missing on error" do
      Puppet::Util::Execution.expects(:execute).raises(Puppet::ExecutionFailure.new("ERROR!"))
      expect(provider.query).to eq({
        :ensure => :purged,
        :status => 'missing',
        :name => resource[:name],
        :error => 'ok',
      })
    end
  end #end when querying

end # end describe provider
