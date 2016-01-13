#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:zypper)

describe provider_class do
  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns "mypackage"
    @resource.stubs(:[]).with(:ensure).returns :installed
    @resource.stubs(:command).with(:zypper).returns "/usr/bin/zypper"

    @provider = provider_class.new(@resource)
  end

  it "should have an install method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:uninstall)
  end

  it "should have an update method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:update)
  end

  it "should have a latest method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:latest)
  end

  it "should have a install_options method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:install_options)
  end

  describe "when installing with zypper version >= 1.0" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "1.2.8"

      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "1.2.8"
      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--name', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when installing with zypper version = 0.6.104" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "0.6.104"

      @provider.expects(:zypper).with('--terse', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "0.6.104"
      @provider.expects(:zypper).with('--terse', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when installing with zypper version = 0.6.13" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "0.6.13"

      @provider.expects(:zypper).with('--terse', :install, '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "0.6.13"
      @provider.expects(:zypper).with('--terse', :install, '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when updating" do
    it "should call install method of instance" do
      @provider.expects(:install)
      @provider.update
    end
  end

  describe "when getting latest version" do
    after do described_class.reset! end
    context "when the package has available update" do
      it "should return a version string with valid list-updates data from SLES11sp1" do
        fake_data = File.read(my_fixture('zypper-list-updates-SLES11sp1.out'))
        @resource.stubs(:[]).with(:name).returns "at"
        described_class.expects(:zypper).with("list-updates").returns fake_data
        expect(@provider.latest).to eq("3.1.8-1069.18.2")
      end
    end

    context "when the package is in the latest version" do
      it "should return nil with valid list-updates data from SLES11sp1" do
        fake_data = File.read(my_fixture('zypper-list-updates-SLES11sp1.out'))
        @resource.stubs(:[]).with(:name).returns "zypper-log"
        described_class.expects(:zypper).with("list-updates").returns fake_data
        expect(@provider.latest).to eq(nil)
      end
    end

    context "when there are no updates available" do
      it "should return nil" do
        fake_data_empty = File.read(my_fixture('zypper-list-updates-empty.out'))
        @resource.stubs(:[]).with(:name).returns "at"
        described_class.expects(:zypper).with("list-updates").returns fake_data_empty
        expect(@provider.latest).to eq(nil)
      end
    end
  end

  describe "should install a virtual package" do
    it "when zypper version = 0.6.13" do
      @resource.stubs(:should).with(:ensure).returns :installed
      @resource.stubs(:allow_virtual?).returns true
      @provider.stubs(:zypper_version).returns "0.6.13"
      @provider.expects(:zypper).with('--terse', :install, '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "when zypper version >= 1.0.0" do
      @resource.stubs(:should).with(:ensure).returns :installed
      @resource.stubs(:allow_virtual?).returns true
      @provider.stubs(:zypper_version).returns "1.2.8"
      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when installing with zypper install options" do
    it "should install the package without checking keys" do
      @resource.stubs(:[]).with(:name).returns "php5"
      @resource.stubs(:[]).with(:install_options).returns ['--no-gpg-check', {'-p' => '/vagrant/files/localrepo/'}]
      @resource.stubs(:should).with(:ensure).returns "5.4.10-4.5.6"
      @resource.stubs(:allow_virtual?).returns false
      @provider.stubs(:zypper_version).returns "1.2.8"

      @provider.expects(:zypper).with('--quiet', '--no-gpg-check', :install,
        '--auto-agree-with-licenses', '--no-confirm', '-p=/vagrant/files/localrepo/', 'php5-5.4.10-4.5.6')
      @provider.expects(:query).returns "php5 0 5.4.10 4.5.6 x86_64"
      @provider.install
    end

    it "should install package with hash install options" do
      @resource.stubs(:[]).with(:name).returns 'vim'
      @resource.stubs(:[]).with(:install_options).returns([{ '--a' => 'foo', '--b' => '"quoted bar"' }])
      @resource.stubs(:should).with(:ensure).returns :present
      @resource.stubs(:allow_virtual?).returns false

      @provider.stubs(:zypper_version).returns '1.2.8'
      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a=foo', '--b="quoted bar"', '--name', 'vim')
      @provider.expects(:query).returns 'package vim is not installed'
      @provider.install
    end

    it "should install package with array install options" do
      @resource.stubs(:[]).with(:name).returns 'vim'
      @resource.stubs(:[]).with(:install_options).returns([['--a', '--b', '--c']])
      @resource.stubs(:should).with(:ensure).returns :present
      @resource.stubs(:allow_virtual?).returns false

      @provider.stubs(:zypper_version).returns '1.2.8'
      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a', '--b', '--c', '--name', 'vim')
      @provider.expects(:query).returns 'package vim is not installed'
      @provider.install
    end

    it "should install package with string install options" do
      @resource.stubs(:[]).with(:name).returns 'vim'
      @resource.stubs(:[]).with(:install_options).returns(['--a --b --c'])
      @resource.stubs(:should).with(:ensure).returns :present
      @resource.stubs(:allow_virtual?).returns false

      @provider.stubs(:zypper_version).returns '1.2.8'
      @provider.expects(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a --b --c', '--name', 'vim')
      @provider.expects(:query).returns 'package vim is not installed'
      @provider.install
    end
  end

  describe 'when uninstalling' do
    it 'should use remove to uninstall on zypper version 1.6 and above' do
      @provider.stubs(:zypper_version).returns '1.6.308'
      @provider.expects(:zypper).with(:remove, '--no-confirm', 'mypackage')
      @provider.uninstall
    end

    it 'should use remove  --force-solution to uninstall on zypper versions between 1.0 and 1.6' do
      @provider.stubs(:zypper_version).returns '1.0.2'
      @provider.expects(:zypper).with(:remove, '--no-confirm', '--force-resolution', 'mypackage')
      @provider.uninstall
    end
  end
end
