#!/usr/bin/env rspec
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
      @instances = described_class.instances.map { |p| Hash.new(:name => p.get(:name), :ensure => p.get(:ensure)) }
      @instances.size.should == 4
      @instances[0].should == Hash.new(:name => 'SUNPython', :ensure => :present)
      @instances[1].should == Hash.new(:name => 'SUNWbind', :ensure => :present)
      @instances[2].should == Hash.new(:name => 'SUNWdistro-license-copyright', :ensure => :present)
      @instances[3].should == Hash.new(:name => 'SUNWfppd', :ensure => :present)
    end

    it "should correctly parse lines with non preferred publisher" do
      described_class.expects(:pkg).with(:list,'-H').returns File.read(my_fixture('publisher'))
      @instances = described_class.instances.map { |p| Hash.new(:name => p.get(:name), :ensure => p.get(:ensure)) }
      @instances.size.should == 2
      @instances[0].should == Hash.new(:name => 'SUNWpcre', :ensure => :present)
      @instances[1].should == Hash.new(:name => 'service/network/ssh', :ensure => :present)
    end

    it "should warn about incorrect lines" do
      fake_output = File.read(my_fixture('incomplete'))
      error_line = fake_output.lines[0]
      described_class.expects(:pkg).with(:list,'-H').returns fake_output
      described_class.expects(:warning).with "Failed to match 'pkg list' line #{error_line.inspect}"
      described_class.instances
    end
  end

  describe "when query a package" do
    it "should find the package" do
      @provider.stubs(:pkg).with(:list,'-H','dummy').returns File.read(my_fixture('dummy'))
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

    it "should return :absent when the packageline cannot be parsed" do
      @provider.stubs(:pkg).with(:list,'-H','dummy').returns File.read(my_fixture('incomplete'))
      @provider.query.should == {
        :name   => 'dummy',
        :ensure => :absent
      }
    end
  end

end
