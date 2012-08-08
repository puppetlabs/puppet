#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkg) do
  before :each do
    @resource = Puppet::Resource.new(:package, 'dummy', :parameters => {:name => 'dummy', :ensure => :latest})
    @provider = described_class.new(@resource)
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        @provider.should respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  it "should not be versionable" do
    described_class.should_not be_versionable
  end

  it "should use :install to update" do
    @provider.expects(:install)
    @provider.update
  end

  describe "when calling instances" do
    it "should correctly parse lines with preferred publisher" do
      described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('simple'))
      @instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      @instances.size.should == 4
      @instances[0].should == {:name => 'SUNPython', :ensure => :present}
      @instances[1].should == {:name => 'SUNWbind', :ensure => :present}
      @instances[2].should == {:name => 'SUNWdistro-license-copyright', :ensure => :present}
      @instances[3].should == {:name => 'SUNWfppd', :ensure => :present}
    end

    it "should correctly parse lines with non preferred publisher" do
      described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('publisher'))
      @instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      @instances.size.should == 2
      @instances[0].should == {:name => 'SUNWpcre', :ensure => :present}
      @instances[1].should == {:name => 'service/network/ssh', :ensure => :present}
    end

    it "should correctly parse lines on solaris 11" do
      described_class.expects(:pkg).with(:list, '-H').returns File.read(my_fixture('solaris11'))
      described_class.expects(:warning).never
      @instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure) }}
      @instances.size.should == 12
      @instances[0].should == {:name => 'compress/zip', :ensure => :present}
      @instances[1].should == {:name => 'archiver/gnu-tar', :ensure => :present}
      @instances[2].should == {:name => 'compress/bzip2', :ensure => :present}
      @instances[3].should == {:name => 'compress/gzip', :ensure => :present}
      @instances[4].should == {:name => 'compress/p7zip', :ensure => :present}
      @instances[5].should == {:name => 'compress/unzip', :ensure => :present}
      @instances[6].should == {:name => 'compress/zip', :ensure => :present}
      @instances[7].should == {:name => 'x11/library/toolkit/libxaw7', :ensure => :present}
      @instances[8].should == {:name => 'x11/library/toolkit/libxt', :ensure => :present}
      @instances[9].should == {:name => 'shell/bash', :ensure => :present}
      @instances[10].should == {:name => 'shell/zsh', :ensure => :present}
      @instances[11].should == {:name => 'security/sudo', :ensure => :present}
    end

    it "should work correctly for ensure latest on solaris 11 (UFOXI)" do
      described_class.expects(:pkg).with(:list,'-Ha','dummy').returns File.read(my_fixture('dummy_solaris11.installed'))
      @provider.latest.should == 'installed'
    end

    it "should work correctly for ensure latest on solaris 11(known UFOXI)" do
      described_class.expects(:pkg).with(:list,'-Ha','dummy').returns File.read(my_fixture('dummy_solaris11.known'))
      @provider.latest.should == 'known'
    end

    it "should work correctly for ensure latest on solaris 11 (IFO)" do
      described_class.expects(:pkg).with(:list,'-Ha','dummy').returns File.read(my_fixture('dummy_solaris11.ifo.installed'))
      @provider.latest.should == 'installed'
    end

    it "should work correctly for ensure latest on solaris 11(known IFO)" do
      described_class.expects(:pkg).with(:list,'-Ha','dummy').returns File.read(my_fixture('dummy_solaris11.ifo.known'))
      @provider.latest.should == 'known'
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

  describe "when query a package" do

    context "on solaris 10" do
      it "should find the package" do
        @provider.stubs(:pkg).with(:list,'-H','dummy').returns File.read(my_fixture('dummy_solaris10'))
        @provider.query.should == {
          :name     => 'dummy',
          :ensure   => :present,
          :version  => '2.5.5-0.111',
          :status   => "installed",
          :provider => :pkg,
        }
      end

      it "should return :absent when the package is not found" do
        # I dont know what the acutal error looks like, but according to type/pkg.rb we're just
        # reacting on the Exception anyways
        @provider.expects(:pkg).with(:list, "-H", "dummy").raises Puppet::ExecutionFailure, 'Not found'
        @provider.query.should == {:ensure => :absent, :name => "dummy"}
      end
    end

    context "on solaris 11" do
      it "should find the package" do
        @provider.stubs(:pkg).with(:list,'-H','dummy').returns File.read(my_fixture('dummy_solaris11.installed'))
        @provider.query.should == {
          :name     => 'dummy',
          :version  => '1.0.6-0.175.0.0.0.2.537',
          :status   => 'installed',
          :ensure   => :present,
          :provider => :pkg
        }
      end

      it "should return :absent when the package is not found" do
        # I dont know what the acutal error looks like, but according to type/pkg.rb we're just
        # reacting on the Exception anyways
        @provider.expects(:pkg).with(:list, "-H", "dummy").raises Puppet::ExecutionFailure, 'Not found'
        @provider.query.should == {:ensure => :absent, :name => "dummy"}
      end
    end

    it "should return fail when the packageline cannot be parsed" do
      @provider.stubs(:pkg).with(:list,'-H','dummy').returns File.read(my_fixture('incomplete'))
      expect {
        @provider.query
      }.to raise_error(ArgumentError, /Unknown line format/)
    end
  end

  context "#install" do
    it "should accept all licenses" do
      described_class.expects(:pkg).with(:install, '--accept', @resource[:name])
      @provider.install
    end
  end

  context "#uninstall" do
    it "should support current pkg version" do
      described_class.expects(:pkg).with(:version).returns('630e1ffc7a19')
      described_class.expects(:pkg).with([:uninstall, @resource[:name]])
      @provider.uninstall
    end

    it "should support original pkg commands" do
      described_class.expects(:pkg).with(:version).returns('052adf36c3f4')
      described_class.expects(:pkg).with([:uninstall, '-r', @resource[:name]])
      @provider.uninstall
    end
  end
end
