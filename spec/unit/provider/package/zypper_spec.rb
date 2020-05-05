require 'spec_helper'

describe Puppet::Type.type(:package).provider(:zypper) do
  before(:each) do
    # Create a mock resource
    @resource = double('resource')

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name and source
    allow(@resource).to receive(:[]).with(:name).and_return("mypackage")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:installed)
    allow(@resource).to receive(:command).with(:zypper).and_return("/usr/bin/zypper")

    @provider = described_class.new(@resource)
  end

  it "should have an install method" do
    @provider = described_class.new
    expect(@provider).to respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider = described_class.new
    expect(@provider).to respond_to(:uninstall)
  end

  it "should have an update method" do
    @provider = described_class.new
    expect(@provider).to respond_to(:update)
  end

  it "should have a latest method" do
    @provider = described_class.new
    expect(@provider).to respond_to(:latest)
  end

  it "should have a install_options method" do
    @provider = described_class.new
    expect(@provider).to respond_to(:install_options)
  end

  context "when installing with zypper version >= 1.0" do
    it "should use a command-line with versioned package'" do
      allow(@resource).to receive(:should).with(:ensure).and_return("1.2.3-4.5.6")
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("1.2.8")

      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end

    it "should use a command-line without versioned package" do
      allow(@resource).to receive(:should).with(:ensure).and_return(:latest)
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("1.2.8")
      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--name', 'mypackage')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end
  end

  context "when installing with zypper version = 0.6.104" do
    it "should use a command-line with versioned package'" do
      allow(@resource).to receive(:should).with(:ensure).and_return("1.2.3-4.5.6")
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("0.6.104")

      expect(@provider).to receive(:zypper).with('--terse', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end

    it "should use a command-line without versioned package" do
      allow(@resource).to receive(:should).with(:ensure).and_return(:latest)
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("0.6.104")
      expect(@provider).to receive(:zypper).with('--terse', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end
  end

  context "when installing with zypper version = 0.6.13" do
    it "should use a command-line with versioned package'" do
      allow(@resource).to receive(:should).with(:ensure).and_return("1.2.3-4.5.6")
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("0.6.13")

      expect(@provider).to receive(:zypper).with('--terse', :install, '--no-confirm', 'mypackage-1.2.3-4.5.6')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end

    it "should use a command-line without versioned package" do
      allow(@resource).to receive(:should).with(:ensure).and_return(:latest)
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("0.6.13")
      expect(@provider).to receive(:zypper).with('--terse', :install, '--no-confirm', 'mypackage')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end
  end

  context "when updating" do
    it "should call install method of instance" do
      expect(@provider).to receive(:install)
      @provider.update
    end
  end

  context "when getting latest version" do
    after { described_class.reset! }

    context "when the package has available update" do
      it "should return a version string with valid list-updates data from SLES11sp1" do
        fake_data = File.read(my_fixture('zypper-list-updates-SLES11sp1.out'))
        allow(@resource).to receive(:[]).with(:name).and_return("at")
        expect(described_class).to receive(:zypper).with("list-updates").and_return(fake_data)
        expect(@provider.latest).to eq("3.1.8-1069.18.2")
      end
    end

    context "when the package is in the latest version" do
      it "should return nil with valid list-updates data from SLES11sp1" do
        fake_data = File.read(my_fixture('zypper-list-updates-SLES11sp1.out'))
        allow(@resource).to receive(:[]).with(:name).and_return("zypper-log")
        expect(described_class).to receive(:zypper).with("list-updates").and_return(fake_data)
        expect(@provider.latest).to eq(nil)
      end
    end

    context "when there are no updates available" do
      it "should return nil" do
        fake_data_empty = File.read(my_fixture('zypper-list-updates-empty.out'))
        allow(@resource).to receive(:[]).with(:name).and_return("at")
        expect(described_class).to receive(:zypper).with("list-updates").and_return(fake_data_empty)
        expect(@provider.latest).to eq(nil)
      end
    end
  end

  context "should install a virtual package" do
    it "when zypper version = 0.6.13" do
      allow(@resource).to receive(:should).with(:ensure).and_return(:installed)
      allow(@resource).to receive(:allow_virtual?).and_return(true)
      allow(@provider).to receive(:zypper_version).and_return("0.6.13")
      expect(@provider).to receive(:zypper).with('--terse', :install, '--no-confirm', 'mypackage')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end

    it "when zypper version >= 1.0.0" do
      allow(@resource).to receive(:should).with(:ensure).and_return(:installed)
      allow(@resource).to receive(:allow_virtual?).and_return(true)
      allow(@provider).to receive(:zypper_version).and_return("1.2.8")
      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      expect(@provider).to receive(:query).and_return("mypackage 0 1.2.3 4.5.6 x86_64")
      @provider.install
    end
  end

  context "when installing with zypper install options" do
    it "should install the package without checking keys" do
      allow(@resource).to receive(:[]).with(:name).and_return("php5")
      allow(@resource).to receive(:[]).with(:install_options).and_return(['--no-gpg-check', {'-p' => '/vagrant/files/localrepo/'}])
      allow(@resource).to receive(:should).with(:ensure).and_return("5.4.10-4.5.6")
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("1.2.8")

      expect(@provider).to receive(:zypper).with('--quiet', '--no-gpg-check', :install,
        '--auto-agree-with-licenses', '--no-confirm', '-p=/vagrant/files/localrepo/', 'php5-5.4.10-4.5.6')
      expect(@provider).to receive(:query).and_return("php5 0 5.4.10 4.5.6 x86_64")
      @provider.install
    end

    it "should install the package with --no-gpg-checks" do
      allow(@resource).to receive(:[]).with(:name).and_return("php5")
      allow(@resource).to receive(:[]).with(:install_options).and_return(['--no-gpg-checks', {'-p' => '/vagrant/files/localrepo/'}])
      allow(@resource).to receive(:should).with(:ensure).and_return("5.4.10-4.5.6")
      allow(@resource).to receive(:allow_virtual?).and_return(false)
      allow(@provider).to receive(:zypper_version).and_return("1.2.8")

      expect(@provider).to receive(:zypper).with('--quiet', '--no-gpg-checks', :install,
        '--auto-agree-with-licenses', '--no-confirm', '-p=/vagrant/files/localrepo/', 'php5-5.4.10-4.5.6')
      expect(@provider).to receive(:query).and_return("php5 0 5.4.10 4.5.6 x86_64")
      @provider.install
    end

    it "should install package with hash install options" do
      allow(@resource).to receive(:[]).with(:name).and_return('vim')
      allow(@resource).to receive(:[]).with(:install_options).and_return([{ '--a' => 'foo', '--b' => '"quoted bar"' }])
      allow(@resource).to receive(:should).with(:ensure).and_return(:present)
      allow(@resource).to receive(:allow_virtual?).and_return(false)

      allow(@provider).to receive(:zypper_version).and_return('1.2.8')
      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a=foo', '--b="quoted bar"', '--name', 'vim')
      expect(@provider).to receive(:query).and_return('package vim is not installed')
      @provider.install
    end

    it "should install package with array install options" do
      allow(@resource).to receive(:[]).with(:name).and_return('vim')
      allow(@resource).to receive(:[]).with(:install_options).and_return([['--a', '--b', '--c']])
      allow(@resource).to receive(:should).with(:ensure).and_return(:present)
      allow(@resource).to receive(:allow_virtual?).and_return(false)

      allow(@provider).to receive(:zypper_version).and_return('1.2.8')
      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a', '--b', '--c', '--name', 'vim')
      expect(@provider).to receive(:query).and_return('package vim is not installed')
      @provider.install
    end

    it "should install package with string install options" do
      allow(@resource).to receive(:[]).with(:name).and_return('vim')
      allow(@resource).to receive(:[]).with(:install_options).and_return(['--a --b --c'])
      allow(@resource).to receive(:should).with(:ensure).and_return(:present)
      allow(@resource).to receive(:allow_virtual?).and_return(false)

      allow(@provider).to receive(:zypper_version).and_return('1.2.8')
      expect(@provider).to receive(:zypper).with('--quiet', :install, '--auto-agree-with-licenses', '--no-confirm', '--a --b --c', '--name', 'vim')
      expect(@provider).to receive(:query).and_return('package vim is not installed')
      @provider.install
    end
  end

  context 'when uninstalling' do
    it 'should use remove to uninstall on zypper version 1.6 and above' do
      allow(@provider).to receive(:zypper_version).and_return('1.6.308')
      expect(@provider).to receive(:zypper).with(:remove, '--no-confirm', 'mypackage')
      @provider.uninstall
    end

    it 'should use remove  --force-solution to uninstall on zypper versions between 1.0 and 1.6' do
      allow(@provider).to receive(:zypper_version).and_return('1.0.2')
      expect(@provider).to receive(:zypper).with(:remove, '--no-confirm', '--force-resolution', 'mypackage')
      @provider.uninstall
    end
  end
end
