require 'spec_helper'

describe Puppet::Type.type(:package).provider(:sun) do
  let(:resource) { Puppet::Type.type(:package).new(:name => 'dummy', :ensure => :installed, :provider => :sun) }
  let(:provider) { resource.provider }

  describe 'provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_upgradeable }
    it { is_expected.not_to be_versionable }
  end

  [:install, :uninstall, :latest, :query, :update].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end
  end

  context '#install' do
    it "should install a package" do
      resource[:ensure] = :installed
      resource[:source] = '/cdrom'
      expect(provider).to receive(:pkgadd).with(['-d', '/cdrom', '-n', 'dummy'])
      provider.install
    end

    it "should install a package if it is not present on update" do
      expect(provider).to receive(:pkginfo).with('-l', 'dummy').and_return(File.read(my_fixture('dummy.server')))
      expect(provider).to receive(:pkgrm).with(['-n', 'dummy'])
      expect(provider).to receive(:install)
      provider.update
    end

     it "should install a package on global zone if -G specified" do
      resource[:ensure] = :installed
      resource[:source] = '/cdrom'
      resource[:install_options] = '-G'
      expect(provider).to receive(:pkgadd).with(['-d', '/cdrom', '-G', '-n', 'dummy'])
      provider.install
    end
  end

  context '#uninstall' do
    it "should uninstall a package" do
      expect(provider).to receive(:pkgrm).with(['-n','dummy'])
      provider.uninstall
    end
  end

  context '#update' do
    it "should call uninstall if not :absent on info2hash" do
      allow(provider).to receive(:info2hash).and_return({:name => 'SUNWdummy', :ensure => "11.11.0,REV=2010.10.12.04.23"})
      expect(provider).to receive(:uninstall)
      expect(provider).to receive(:install)
      provider.update
    end

    it "should not call uninstall if :absent on info2hash" do
      allow(provider).to receive(:info2hash).and_return({:name => 'SUNWdummy', :ensure => :absent})
      expect(provider).to receive(:install)
      provider.update
    end
  end

  context '#query' do
    it "should find the package on query" do
      expect(provider).to receive(:pkginfo).with('-l', 'dummy').and_return(File.read(my_fixture('dummy.server')))
      expect(provider.query).to eq({
        :name     => 'SUNWdummy',
        :category=>"system",
        :platform=>"i386",
        :ensure   => "11.11.0,REV=2010.10.12.04.23",
        :root=>"/",
        :description=>"Dummy server (9.6.1-P3)",
        :vendor => "Oracle Corporation",
      })
    end

    it "shouldn't find the package on query if it is not present" do
      expect(provider).to receive(:pkginfo).with('-l', 'dummy').and_raise(Puppet::ExecutionFailure, "Execution of 'pkginfo -l dummy' returned 3: ERROR: information for \"dummy\" not found.")
      expect(provider.query).to eq({:ensure => :absent})
    end

    it "unknown message should raise error." do
      expect(provider).to receive(:pkginfo).with('-l', 'dummy').and_return('RANDOM')
      expect { provider.query }.to raise_error Puppet::Error
    end
  end

  context '#instance' do
    it "should list instances when there are packages in the system" do
      expect(described_class).to receive(:pkginfo).with('-l').and_return(File.read(my_fixture('simple')))
      instances = provider.class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      expect(instances.size).to eq(2)
      expect(instances[0]).to eq({
        :name     => 'SUNWdummy',
        :ensure   => "11.11.0,REV=2010.10.12.04.23",
      })
      expect(instances[1]).to eq({
        :name     => 'SUNWdummyc',
        :ensure   => "11.11.0,REV=2010.10.12.04.24",
      })
    end

    it "should return empty if there were no packages" do
      expect(described_class).to receive(:pkginfo).with('-l').and_return('')
      instances = provider.class.instances
      expect(instances.size).to eq(0)
    end
  end
end
