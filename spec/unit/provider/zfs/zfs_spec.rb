#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:zfs).provider(:zfs) do
  let(:name) { 'myzfs' }
  let(:zfs) { '/usr/sbin/zfs' }

  let(:resource) do
    Puppet::Type.type(:zfs).new(:name => name, :provider => :zfs)
  end

  let(:provider) { resource.provider }

  before do
    provider.class.stubs(:which).with('zfs').returns(zfs)
  end

  context ".instances" do
    it "should have an instances method" do
      provider.class.should respond_to(:instances)
    end

    it "should list instances" do
      provider.class.expects(:zfs).with(:list,'-H').returns File.read(my_fixture('zfs-list.out'))
      instances = provider.class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      instances.size.should == 2
      instances[0].should == {:name => 'rpool', :ensure => :present}
      instances[1].should == {:name => 'rpool/ROOT', :ensure => :present}
    end
  end

  context '#add_properties' do
    it 'should return an array of properties' do
      resource[:mountpoint] = '/foo'

      provider.add_properties.should == ['-o', "mountpoint=/foo"]
    end

    it 'should return an empty array' do
      provider.add_properties.should == []
    end
  end

  context "#create" do
    it "should execute zfs create" do
      provider.expects(:zfs).with(:create, name)

      provider.create
    end

    Puppet::Type.type(:zfs).validproperties.each do |prop|
      next if prop == :ensure
      it "should include property #{prop}" do
        resource[prop] = prop

        provider.expects(:zfs).with(:create, '-o', "#{prop}=#{prop}", name)

        provider.create
      end
    end
  end

  context "#destroy" do
    it "should execute zfs destroy" do
      provider.expects(:zfs).with(:destroy, name)

      provider.destroy
    end
  end

  context "#exists?" do
    it "should return true if the resource exists" do
      #return stuff because we have to slice and dice it
      provider.expects(:zfs).with(:list).returns("NAME USED AVAIL REFER MOUNTPOINT\nmyzfs 100K 27.4M /myzfs")

      provider.should be_exists
    end

    it "should return false if returned values don't match the name" do
      provider.expects(:zfs).with(:list).returns("no soup for you")

      provider.should_not be_exists
    end
  end

  describe "zfs properties" do
    [:aclinherit, :aclmode, :atime, :canmount, :checksum,
     :compression, :copies, :dedup, :devices, :exec, :logbias,
     :mountpoint, :nbmand,  :primarycache, :quota, :readonly,
     :recordsize, :refquota, :refreservation, :reservation,
     :secondarycache, :setuid, :shareiscsi, :sharenfs, :sharesmb,
     :snapdir, :version, :volsize, :vscan, :xattr, :zoned].each do |prop|
      it "should get #{prop}" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', prop, name).returns("value\n")

        provider.send(prop).should == 'value'
      end

      it "should set #{prop}=value" do
        provider.expects(:zfs).with(:set, "#{prop}=value", name)

        provider.send("#{prop}=", "value")
      end
    end
  end
end
