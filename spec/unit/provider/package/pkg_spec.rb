#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkg) do
  let (:resource) { Puppet::Resource.new(:package, 'dummy', :parameters => {:name => 'dummy', :ensure => :latest}) }
  let (:provider) { described_class.new(resource) }
  before :each do
    described_class.stubs(:command).with(:pkg).returns('/bin/pkg')
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        provider.should respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  it "should be versionable" do
    described_class.should be_versionable
  end

  describe "#methods" do
    context ":pkg_state" do
      it "should raise error on unknown values" do
        expect {
          described_class.pkg_state('extra').should
        }.to raise_error(ArgumentError, /Unknown format/)
      end
      ['known', 'installed'].each do |k|
        it "should return known values" do
          described_class.pkg_state(k).should == {:status => k}
        end
      end
    end
    context ":ifo_flag" do
      it "should raise error on unknown values" do
        expect {
          described_class.ifo_flag('x--').should
        }.to raise_error(ArgumentError, /Unknown format/)
      end
      {'i--' => 'installed', '---'=> 'known'}.each do |k, v|
        it "should return known values" do
          described_class.ifo_flag(k).should == {:status => v}
        end
      end
    end
    context ":parse_line" do
      it "should raise error on unknown values" do
        expect {
          described_class.parse_line('pkg (mypkg) 1.2.3.4 i-- zzz').should
        }.to raise_error(ArgumentError, /Unknown line format/)
      end
      {
        'spkg       0.0.7  i--' => {:name => 'spkg', :ensure => '0.0.7', :status => 'installed', :provider => :pkg},
        'spkg (me)  0.0.7  i--' => {:name => 'spkg', :ensure => '0.0.7', :status => 'installed', :provider => :pkg, :publisher => 'me'},
        'spkg (me)  0.0.7  if-' => {:name => 'spkg', :ensure => 'held', :status => 'installed', :provider => :pkg, :publisher => 'me'},
        'spkg       0.0.7  installed -----' => {:name => 'spkg', :ensure => '0.0.7', :status => 'installed', :provider => :pkg},
        'spkg (me)  0.0.7  installed -----' => {:name => 'spkg', :ensure => '0.0.7', :status => 'installed', :provider => :pkg, :publisher => 'me'},
       }.each do |k, v|
        it "[#{k}] should correctly parse" do
          described_class.parse_line(k).should == v
        end
      end
    end
    context ":latest" do
      it "should work correctly for ensure latest on solaris 11 (UFOXI) when there are no further packages to install" do
        described_class.expects(:pkg).with(:list,'-Hn','dummy').returns File.read(my_fixture('dummy_solaris11.installed'))
        provider.latest.should == "1.0.6-0.175.0.0.0.2.537"
      end
      it "should work correctly for ensure latest on solaris 11 in the presence of a certificate expiration warning" do
        described_class.expects(:pkg).with(:list,'-Hn','dummy').returns File.read(my_fixture('dummy_solaris11.certificate_warning'))
        provider.latest.should == "1.0.6-0.175.0.0.0.2.537"
      end
      it "should work correctly for ensure latest on solaris 11(known UFOXI)" do
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'update', '-n', 'dummy'], {:failonfail => false, :combine => true}).returns ''
        $CHILD_STATUS.stubs(:exitstatus).returns 0

        described_class.expects(:pkg).with(:list,'-Hn','dummy').returns File.read(my_fixture('dummy_solaris11.known'))
        provider.latest.should == "1.0.6-0.175.0.0.0.2.537"
      end
      it "should work correctly for ensure latest on solaris 11 (IFO)" do
        described_class.expects(:pkg).with(:list,'-Hn','dummy').returns File.read(my_fixture('dummy_solaris11.ifo.installed'))
        provider.latest.should == "1.0.6-0.175.0.0.0.2.537"
      end
      it "should work correctly for ensure latest on solaris 11(known IFO)" do
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'update', '-n', 'dummy'], {:failonfail => false, :combine => true}).returns ''
        $CHILD_STATUS.stubs(:exitstatus).returns 0

        described_class.expects(:pkg).with(:list,'-Hn','dummy').returns File.read(my_fixture('dummy_solaris11.ifo.known'))
        provider.latest.should == "1.0.6-0.175.0.0.0.2.537"
      end
    end
    context ":instances" do
      it "should correctly parse lines with preferred publisher" do
        described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('simple'))
        instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
        instances.size.should == 2
        instances[0].should == {:name => 'SUNWdummy', :ensure => "2.5.5-0.111"}
        instances[1].should == {:name => 'dummy2', :ensure =>"9.3.6.1-0.111"}
      end
      it "should correctly parse lines with non preferred publisher" do
        described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('publisher'))
        instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
        instances.size.should == 2
        instances[0].should == {:name => 'SUNWdummy', :ensure => "8.8-0.111"}
        instances[1].should == {:name => 'service/network/dummy', :ensure => "0.5.11-0.151.0.1"}
      end
      it "should correctly parse lines on solaris 11" do
        described_class.expects(:pkg).with(:list, '-H').returns File.read(my_fixture('solaris11'))
        described_class.expects(:warning).never
        instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure) }}
        instances.size.should == 2
        instances[0].should == {:name => 'dummy/dummy', :ensure => "3.0-0.175.0.0.0.2.537"}
        instances[1].should == {:name => 'dummy/dummy2', :ensure => "1.8.1.2-0.175.0.0.0.2.537"}
      end
      it "should fail on incorrect lines" do
        fake_output = File.read(my_fixture('incomplete'))
        described_class.expects(:pkg).with(:list,'-H').returns fake_output
        expect {
          described_class.instances
        }.to raise_error(ArgumentError, /Unknown line format pkg/)
      end
      it "should fail on unknown package status" do
        described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('unknown_status'))
        expect {
          described_class.instances
        }.to raise_error(ArgumentError, /Unknown format pkg/)
      end
    end
    context ":query" do
      context "on solaris 10" do
        it "should find the package" do
          Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns File.read(my_fixture('dummy_solaris10'))
          $CHILD_STATUS.stubs(:exitstatus).returns 0
          provider.query.should == {
            :name     => 'dummy',
            :ensure   => "2.5.5-0.111",
            :status   => "installed",
            :provider => :pkg,
          }
        end
        it "should return :absent when the package is not found" do
          Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns ''
          $CHILD_STATUS.stubs(:exitstatus).returns 1
          provider.query.should == {:ensure => :absent, :name => "dummy"}
        end
      end
      context "on solaris 11" do
        it "should find the package" do
          $CHILD_STATUS.stubs(:exitstatus).returns 0
          Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns File.read(my_fixture('dummy_solaris11.installed'))
          provider.query.should == {
            :name     => 'dummy',
            :status   => 'installed',
            :ensure   => "1.0.6-0.175.0.0.0.2.537",
            :provider => :pkg
          }
        end
        it "should return :absent when the package is not found" do
          Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns ''
          $CHILD_STATUS.stubs(:exitstatus).returns 1
          provider.query.should == {:ensure => :absent, :name => "dummy"}
        end
      end
      it "should return fail when the packageline cannot be parsed" do
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns(File.read(my_fixture('incomplete')))
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect {
          provider.query
        }.to raise_error(ArgumentError, /Unknown line format/)
      end
    end

    context ":install" do
      it "should accept all licenses" do
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy'], {:failonfail => false, :combine => true}).returns ''
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true}).returns ''
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.install
      end

      it "should install specific version(1)" do
        # Should install also check if the version installed is the same version we are asked to install? or should we rely on puppet for that?
        resource[:ensure] = '0.0.7'
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns 'dummy       0.0.6  installed -----'
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy@0.0.7'], {:failonfail => false, :combine => true}).returns ''
        provider.install
      end
      it "should install specific version(2)" do
        resource[:ensure] = '0.0.8'
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'list', '-H', 'dummy'], {:failonfail => false, :combine => true}).returns 'dummy       0.0.7  installed -----'
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy@0.0.8'], {:failonfail => false, :combine => true}).returns ''
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.install
      end
      it "should install specific version(3)" do
        resource[:ensure] = '0.0.7'
        provider.expects(:query).with().returns({:ensure => '0.0.8'})
        provider.expects(:uninstall).with()
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy@0.0.7'], {:failonfail => false, :combine => true}).returns ''
        provider.install
      end
      it "should install any if version is not specified" do
        resource[:ensure] = :present
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy'], {:failonfail => false, :combine => true}).returns ''
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.install
      end
      it "should install if no version was previously installed, and a specific version was requested" do
        resource[:ensure] = '0.0.7'
        provider.expects(:query).with().returns({:ensure => :absent})
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'unfreeze', 'dummy'], {:failonfail => false, :combine => true})
        Puppet::Util::Execution.expects(:execute).with(['/bin/pkg', 'install', '--accept', 'dummy@0.0.7'], {:failonfail => false, :combine => true}).returns ''
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.install
      end

    end

    context ":update" do
      it "should not raise error if not necessary" do
        provider.expects(:install).with(true).returns({:exit => 0})
        provider.update
      end
      it "should not raise error if not necessary (2)" do
        provider.expects(:install).with(true).returns({:exit => 4})
        provider.update
      end
      it "should raise error if necessary" do
        provider.expects(:install).with(true).returns({:exit => 1})
        expect {
          provider.update
        }.to raise_error(Puppet::Error, /Unable to update/)
      end
    end

    context ":uninstall" do
      it "should support current pkg version" do
        described_class.expects(:pkg).with(:version).returns('630e1ffc7a19')
        described_class.expects(:pkg).with([:uninstall, resource[:name]])
        provider.uninstall
      end
      it "should support original pkg commands" do
        described_class.expects(:pkg).with(:version).returns('052adf36c3f4')
        described_class.expects(:pkg).with([:uninstall, '-r', resource[:name]])
        provider.uninstall
      end
    end
  end
end
