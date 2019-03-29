require 'spec_helper'

describe Puppet::Type.type(:package).provider(:opkg) do

  let(:resource) do
    Puppet::Type.type(:package).new(:name => 'package')
  end

  let(:provider) { described_class.new(resource) }

  before do
    allow(Puppet::Util).to receive(:which).with("opkg").and_return("/bin/opkg")
    allow(provider).to receive(:package_lists).and_return(['.', '..', 'packages'])
  end

  describe "when installing" do
    before do
      allow(provider).to receive(:query).and_return({ :ensure => '1.0' })
    end

    context "when the package list is absent" do
      before do
        allow(provider).to receive(:package_lists).and_return(['.', '..'])  #empty, no package list
      end

      it "fetches the package list when installing" do
        expect(provider).to receive(:opkg).with('update')
        expect(provider).to receive(:opkg).with("--force-overwrite", "install", resource[:name])

        provider.install
      end
    end

    context "when the package list is present" do
      before do
        allow(provider).to receive(:package_lists).and_return(['.', '..', 'lists'])  # With a pre-downloaded package list
      end

      it "fetches the package list when installing" do
        expect(provider).not_to receive(:opkg).with('update')
        expect(provider).to receive(:opkg).with("--force-overwrite", "install", resource[:name])

        provider.install
      end
    end

    it "should call opkg install" do
      expect(Puppet::Util::Execution).to receive(:execute).with(["/bin/opkg", "--force-overwrite", "install", resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
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
            expect(Puppet::Util::Execution).to receive(:execute).with(["/bin/opkg", "--force-overwrite", "install", resource[:source]], {:failonfail => true, :combine => true, :custom_environment => {}})
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
          expect(Puppet::Util::Execution).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new("", 0))
          provider.install
        end
      end

      context "with invalid URL for opkg" do
        before do
          # Emulate the `opkg` command returning a non-zero exit value
          allow(Puppet::Util::Execution).to receive(:execute).and_raise(Puppet::ExecutionFailure, 'oops')
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
      expect(provider).to receive(:install).and_return("install return value")
      expect(provider.update).to eq("install return value")
    end
  end

  describe "when uninstalling" do
    it "should run opkg remove bla" do
      expect(Puppet::Util::Execution).to receive(:execute).with(["/bin/opkg", "remove", resource[:name]], {:failonfail => true, :combine => true, :custom_environment => {}})
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
        allow(Puppet::Util).to receive(:which).with("opkg").and_return("/bin/opkg")
        allow(described_class).to receive(:which).with("opkg").and_return("/bin/opkg")
        expect(described_class).to receive(:execpipe).with("/bin/opkg list-installed").and_yield(packages)

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
      expect(Puppet::Util::Execution).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new("", 0))
      expect(provider.query).to be_nil
    end

    it "should return a hash indicating that the package is missing on error" do
      expect(Puppet::Util::Execution).to receive(:execute).and_raise(Puppet::ExecutionFailure.new("ERROR!"))
      expect(provider.query).to eq({
        :ensure => :purged,
        :status => 'missing',
        :name => resource[:name],
        :error => 'ok',
      })
    end
  end
end
