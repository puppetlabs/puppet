#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:yum)

describe provider do
  before do
    # Create a mock resource
     @resource = stub 'resource'
     @resource.stubs(:[]).with(:name).returns 'mypackage'
     @provider = provider.new(@resource)
     @provider.stubs(:resource).returns @resource
     @provider.stubs(:yum).returns 'yum'
     @provider.stubs(:rpm).returns 'rpm'
     @provider.stubs(:get).with(:name).returns 'mypackage'
     @provider.stubs(:get).with(:version).returns '1'
     @provider.stubs(:get).with(:release).returns '1'
     @provider.stubs(:get).with(:arch).returns 'i386'
  end
  # provider should repond to the following methods
   [:install, :latest, :update, :purge].each do |method|
     it "should have a(n) #{method}" do
       @provider.should respond_to(method)
    end
  end

  describe 'when installing' do
    it 'should call yum install for :installed' do
      @resource.stubs(:should).with(:ensure).returns :installed
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, 'mypackage')
      @provider.install
    end

    it 'should use :install to update' do
      @provider.expects(:install)
      @provider.update
    end

    it 'should be able to set version' do
      @resource.stubs(:should).with(:ensure).returns '1.2'
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, 'mypackage-1.2')
      @provider.stubs(:query).returns :ensure => '1.2'
      @provider.install
    end

    it 'should be able to downgrade' do
      @resource.stubs(:should).with(:ensure).returns '1.0'
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :downgrade, 'mypackage-1.0')
      @provider.stubs(:query).returns(:ensure => '1.2').then.returns(:ensure => '1.0')
      @provider.install
    end
  end

  describe 'when uninstalling' do
    it 'should use erase to purge' do
      @provider.expects(:yum).with('-y', :erase, 'mypackage')
      @provider.purge
    end

    it 'should use rpm to uninstall' do
      @provider.expects(:rpm).with('-e', 'mypackage-1-1.i386')
      @provider.uninstall
    end
  end

  it 'should be versionable' do
    provider.should be_versionable
  end

  describe '#latest' do
    describe 'when latest_info is nil' do
      before :each do
        @provider.stubs(:latest_info).returns(nil)
      end

      it 'raises if ensure is absent and latest_info is nil' do
        @provider.stubs(:properties).returns({:ensure => :absent})

        expect { @provider.latest }.to raise_error(
          Puppet::DevError,
          'Tried to get latest on a missing package'
        )
      end

      it 'returns the ensure value if the package is not already installed' do
        @provider.stubs(:properties).returns({:ensure => '3.4.5'})

        @provider.latest.should == '3.4.5'
      end
    end

    describe 'when latest_info is populated' do
      before :each do
        @provider.stubs(:latest_info).returns({
          :name     => 'mypackage',
          :epoch    => '1',
          :version  => '2.3.4',
          :release  => '5',
          :arch     => 'i686',
          :provider => :yum,
          :ensure   => '2.3.4-5'
        })
      end

      it 'includes the epoch in the version string' do
        @provider.latest.should == '1:2.3.4-5'
      end
    end
  end
end
