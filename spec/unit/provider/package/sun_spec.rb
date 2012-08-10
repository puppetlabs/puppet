#! /usr/bin/env ruby -S rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:sun)

describe provider_class do
  let(:resource) { Puppet::Resource.new(:package, 'dummy', :parameters => {:name => 'dummy', :ensure => :installed}) }
  let(:provider) { provider_class.new(resource) }

  before(:each) do
    resource[:name] = 'dummy'
    resource[:adminfile] = nil
    resource[:responsefile] = nil

    # Stub some provider methods to avoid needing the actual software
    # installed, so we can test on whatever platform we want.
    provider_class.stubs(:command).with(:pkginfo).returns('/usr/bin/pkginfo')
    provider_class.stubs(:command).with(:pkgadd).returns('/usr/sbin/pkgadd')
    provider_class.stubs(:command).with(:pkgrm).returns('/usr/sbin/pkgrm')
  end

  describe 'provider features' do
    it { should be_installable }
    it { should be_uninstallable }
    it { should be_upgradeable }
    it { should_not be_versionable }
  end

  [:install, :uninstall, :latest, :query, :update].each do |method|
    it "should have a #{method} method" do
      provider.should respond_to(method)
    end
  end

  context '#install' do
    it "should install a package" do
      resource[:ensure] = :installed
      resource[:source] = '/cdrom'
      provider.expects(:pkgadd).with(['-d', '/cdrom', '-n', 'dummy'])
      provider.install
    end

    it "should install a package if it is not present on update" do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l', 'dummy'], {:failonfail => false}).returns File.read(my_fixture('dummy.server'))
      provider.expects(:pkgrm).with(['-n', 'dummy'])
      provider.expects(:install)
      provider.update
    end
  end

  context '#uninstall' do
    it "should uninstall a package" do
      provider.expects(:pkgrm).with(['-n','dummy'])
      provider.uninstall
    end
  end

  context '#update' do
    it "should call uninstall if not :absent on info2hash" do
      provider.stubs(:info2hash).returns({:name => 'SUNWdummy', :ensure => "11.11.0,REV=2010.10.12.04.23"})
      provider.expects(:uninstall)
      provider.expects(:install)
      provider.update
    end

    it "should not call uninstall if :absent on info2hash" do
      provider.stubs(:info2hash).returns({:name => 'SUNWdummy', :ensure => :absent})
      provider.expects(:install)
      provider.update
    end
  end

  context '#query' do
    it "should find the package on query" do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l', 'dummy'], {:failonfail => false}).returns File.read(my_fixture('dummy.server'))
      provider.query.should == {
        :name     => 'SUNWdummy',
        :category=>"system",
        :platform=>"i386",
        :ensure   => "11.11.0,REV=2010.10.12.04.23",
        :root=>"/",
        :description=>"Dummy server (9.6.1-P3)",
        :vendor => "Oracle Corporation",
      }
    end

    it "shouldn't find the package on query if it is not present" do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l', 'dummy'], {:failonfail => false}).returns 'ERROR: information for "dummy" not found.'
      provider.query.should == {:ensure => :absent}
    end

    it "unknown message should raise error." do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l', 'dummy'], {:failonfail => false}).returns 'RANDOM'
      lambda { provider.query }.should raise_error(Puppet::Error)
    end
  end

  context '#instance' do
    it "should list instances when there are packages in the system" do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l']).returns File.read(my_fixture('simple'))
      instances = provider_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      instances.size.should == 2
      instances[0].should == {
        :name     => 'SUNWdummy',
        :ensure   => "11.11.0,REV=2010.10.12.04.23",
      }
      instances[1].should == {
        :name     => 'SUNWdummyc',
        :ensure   => "11.11.0,REV=2010.10.12.04.24",
      }
    end

    it "should return empty if there were no packages" do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/pkginfo', '-l']).returns ''
      instances = provider_class.instances
      instances.size.should == 0
    end

  end
end
