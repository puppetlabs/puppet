#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:apt)

describe provider_class do
  let(:name) { 'asdf' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => name,
      :provider => 'apt'
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  it "should be the default provider on :osfamily => Debian" do
    Facter.expects(:value).with(:osfamily).returns("Debian")
    expect(described_class.default?).to be_truthy
  end

  it "should be versionable" do
    expect(provider_class).to be_versionable
  end

  it "should use :install to update" do
    provider.expects(:install)
    provider.update
  end

  it "should use 'apt-get remove' to uninstall" do
    provider.expects(:aptget).with("-y", "-q", :remove, name)
    provider.uninstall
  end

  it "should use 'apt-get purge' and 'dpkg purge' to purge" do
    provider.expects(:aptget).with("-y", "-q", :remove, "--purge", name)
    provider.expects(:dpkg).with("--purge", name)
    provider.purge
  end

  it "should use 'apt-cache policy' to determine the latest version of a package" do
    provider.expects(:aptcache).with(:policy, name).returns "#{name}:
Installed: 1:1.0
Candidate: 1:1.1
Version table:
1:1.0
  650 http://ftp.osuosl.org testing/main Packages
*** 1:1.1
  100 /var/lib/dpkg/status"

    expect(provider.latest).to eq("1:1.1")
  end

  it "should print and error and return nil if no policy is found" do
    provider.expects(:aptcache).with(:policy, name).returns "#{name}:"

    provider.expects(:err)
    expect(provider.latest).to be_nil
  end

  it "should be able to preseed" do
    expect(provider).to respond_to(:run_preseed)
  end

  it "should preseed with the provided responsefile when preseeding is called for" do
    resource[:responsefile] = '/my/file'
    Puppet::FileSystem.expects(:exist?).with('/my/file').returns true

    provider.expects(:info)
    provider.expects(:preseed).with('/my/file')

    provider.run_preseed
  end

  it "should not preseed if no responsefile is provided" do
    provider.expects(:info)
    provider.expects(:preseed).never

    provider.run_preseed
  end

  describe "when installing" do
    it "should preseed if a responsefile is provided" do
      resource[:responsefile] = "/my/file"
      provider.expects(:run_preseed)

      provider.stubs(:aptget)
      provider.install
    end

    it "should check for a cdrom" do
      provider.expects(:checkforcdrom)

      provider.stubs(:aptget)
      provider.install
    end

    it "should use 'apt-get install' with the package name if no version is asked for" do
      resource[:ensure] = :installed
      provider.expects(:aptget).with { |*command| command[-1] == name and command[-2] == :install }

      provider.install
    end

    it "should specify the package version if one is asked for" do
      resource[:ensure] = '1.0'
      provider.expects(:aptget).with { |*command| command[-1] == "#{name}=1.0" }

      provider.install
    end

    it "should use --force-yes if a package version is specified" do
      resource[:ensure] = '1.0'
      provider.expects(:aptget).with { |*command| command.include?("--force-yes") }

      provider.install
    end

    it "should do a quiet install" do
      provider.expects(:aptget).with { |*command| command.include?("-q") }

      provider.install
    end

    it "should default to 'yes' for all questions" do
      provider.expects(:aptget).with { |*command| command.include?("-y") }

      provider.install
    end

    it "should keep config files if asked" do
      resource[:configfiles] = :keep
      provider.expects(:aptget).with { |*command| command.include?("DPkg::Options::=--force-confold") }

      provider.install
    end

    it "should replace config files if asked" do
      resource[:configfiles] = :replace
      provider.expects(:aptget).with { |*command| command.include?("DPkg::Options::=--force-confnew") }

      provider.install
    end

    it 'should support string install options' do
      resource[:install_options] = ['--foo', '--bar']
      provider.expects(:aptget).with('-q', '-y', '-o', 'DPkg::Options::=--force-confold', '--foo', '--bar', :install, name)

      provider.install
    end

    it 'should support hash install options' do
      resource[:install_options] = ['--foo', { '--bar' => 'baz', '--baz' => 'foo' }]
      provider.expects(:aptget).with('-q', '-y', '-o', 'DPkg::Options::=--force-confold', '--foo', '--bar=baz', '--baz=foo', :install, name)

      provider.install
    end
  end
end
