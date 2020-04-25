require 'spec_helper'

describe Puppet::Type.type(:package).provider(:aix) do
  before(:each) do
    # Create a mock resource
    @resource = Puppet::Type.type(:package).new(:name => 'mypackage', :ensure => :installed, :source => 'mysource', :provider => :aix)

    @provider = @resource.provider
  end

  [:install, :uninstall, :latest, :query, :update].each do |method|
    it "should have a #{method} method" do
      expect(@provider).to respond_to(method)
    end
  end

  it "should uninstall a package" do
    expect(@provider).to receive(:installp).with('-gu', 'mypackage')
    expect(@provider.class).to receive(:pkglist).with(:pkgname => 'mypackage').and_return(nil)
    @provider.uninstall
  end

  context "when installing" do
    it "should install a package" do
      allow(@provider).to receive(:query).and_return({:name => 'mypackage', :ensure => 'present', :status => :committed})
      expect(@provider).to receive(:installp).with('-acgwXY', '-d', 'mysource', 'mypackage')
      @provider.install
    end

    it "should install a specific package version" do
      allow(@resource).to receive(:should).with(:ensure).and_return("1.2.3.4")
      allow(@provider).to receive(:query).and_return({:name => 'mypackage', :ensure => '1.2.3.4', :status => :committed})
      expect(@provider).to receive(:installp).with('-acgwXY', '-d', 'mysource', 'mypackage 1.2.3.4')
      @provider.install
    end

    [:broken, :inconsistent].each do |state|
      it "should fail if the installation resulted in a '#{state}' state" do
        allow(@provider).to receive(:query).and_return({:name => 'mypackage', :ensure => 'present', :status => state})
        expect(@provider).to receive(:installp).with('-acgwXY', '-d', 'mysource', 'mypackage')
        expect { @provider.install }.to raise_error(Puppet::Error, "Package 'mypackage' is in a #{state} state and requires manual intervention")
      end
    end

    it "should fail if the specified version is superseded" do
      @resource[:ensure] = '1.2.3.3'
      allow(@provider).to receive(:installp).and_return(<<-OUTPUT)
+-----------------------------------------------------------------------------+
                    Pre-installation Verification...
+-----------------------------------------------------------------------------+
Verifying selections...done
Verifying requisites...done
Results...

WARNINGS
--------
  Problems described in this section are not likely to be the source of any
  immediate or serious failures, but further actions may be necessary or
  desired.

  Already Installed
  -----------------
  The number of selected filesets that are either already installed
  or effectively installed through superseding filesets is 1.  See
  the summaries at the end of this installation for details.

  NOTE:  Base level filesets may be reinstalled using the "Force"
  option (-F flag), or they may be removed, using the deinstall or
  "Remove Software Products" facility (-u flag), and then reinstalled.

  << End of Warning Section >>

+-----------------------------------------------------------------------------+
                   BUILDDATE Verification ...
+-----------------------------------------------------------------------------+
Verifying build dates...done
FILESET STATISTICS
------------------
    1  Selected to be installed, of which:
        1  Already installed (directly or via superseding filesets)
  ----
    0  Total to be installed


Pre-installation Failure/Warning Summary
----------------------------------------
Name                      Level           Pre-installation Failure/Warning
-------------------------------------------------------------------------------
mypackage                 1.2.3.3         Already superseded by 1.2.3.4
      OUTPUT

      expect { @provider.install }.to raise_error(Puppet::Error, "aix package provider is unable to downgrade packages")
    end
  end

  context "when finding the latest version" do
    it "should return the current version when no later version is present" do
      allow(@provider).to receive(:latest_info).and_return(nil)
      allow(@provider).to receive(:properties).and_return({ :ensure => "1.2.3.4" })
      expect(@provider.latest).to eq("1.2.3.4")
    end

    it "should return the latest version of a package" do
      allow(@provider).to receive(:latest_info).and_return({ :version => "1.2.3.5" })
      expect(@provider.latest).to eq("1.2.3.5")
    end

    it "should prefetch the right values" do
      allow(Process).to receive(:euid).and_return(0)
      resource = Puppet::Type.type(:package).
          new(:name => 'sudo.rte', :ensure => :latest,
              :source => 'mysource', :provider => :aix)

      allow(resource).to receive(:should).with(:ensure).and_return(:latest)
      resource.should(:ensure)

      allow(resource.provider.class).to receive(:execute).and_return(<<-END.chomp)
sudo:sudo.rte:1.7.10.4::I:C:::::N:Configurable super-user privileges runtime::::0::
sudo:sudo.rte:1.8.6.4::I:T:::::N:Configurable super-user privileges runtime::::0::
END

      resource.provider.class.prefetch('sudo.rte' => resource)
      expect(resource.provider.latest).to eq('1.8.6.4')
    end
  end

  it "update should install a package" do
    expect(@provider).to receive(:install).with(false)
    @provider.update
  end

  it "should prefetch when some packages lack sources" do
    latest = Puppet::Type.type(:package).new(:name => 'mypackage', :ensure => :latest, :source => 'mysource', :provider => :aix)
    absent = Puppet::Type.type(:package).new(:name => 'otherpackage', :ensure => :absent, :provider => :aix)
    allow(Process).to receive(:euid).and_return(0)
    expect(described_class).to receive(:execute).and_return('mypackage:mypackage.rte:1.8.6.4::I:T:::::N:A Super Cool Package::::0::\n')
    described_class.prefetch({ 'mypackage' => latest, 'otherpackage' => absent })
  end

  context "when querying instances" do
    before(:each) do
      allow(described_class).to receive(:execute).and_return(<<-END.chomp)
sysmgt.cim.providers:sysmgt.cim.providers.metrics:2.12.1.1: : :B: :Metrics Providers for AIX OS: : : : : : :1:0:/:
sysmgt.cim.providers:sysmgt.cim.providers.osbase:2.12.1.1: : :C: :Base Providers for AIX OS: : : : : : :1:0:/:
openssl.base:openssl.base:1.0.2.1800: : :?: :Open Secure Socket Layer: : : : : : :0:0:/:
END
    end

    it "should treat installed packages in broken and inconsistent state as absent" do
      installed_packages = described_class.instances.map { |package| package.properties }
      expected_packages = [{:name => 'sysmgt.cim.providers.metrics', :ensure => :absent, :status => :broken, :provider => :aix},
                           {:name => 'sysmgt.cim.providers.osbase', :ensure => '2.12.1.1', :status => :committed, :provider => :aix},
                           {:name => 'openssl.base', :ensure => :absent, :status => :inconsistent, :provider => :aix}]

      expect(installed_packages).to eql(expected_packages)
    end
  end
end
