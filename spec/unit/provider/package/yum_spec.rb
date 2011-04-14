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
end

