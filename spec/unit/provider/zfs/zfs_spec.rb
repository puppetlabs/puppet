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
      expect(provider.class).to respond_to(:instances)
    end

    it "should list instances" do
      provider.class.expects(:zfs).with(:list,'-H').returns File.read(my_fixture('zfs-list.out'))
      instances = provider.class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      expect(instances.size).to eq(2)
      expect(instances[0]).to eq({:name => 'rpool', :ensure => :present})
      expect(instances[1]).to eq({:name => 'rpool/ROOT', :ensure => :present})
    end
  end

  context '#add_properties' do
    it 'should return an array of properties' do
      resource[:mountpoint] = '/foo'

      expect(provider.add_properties).to eq(['-o', "mountpoint=/foo"])
    end

    it 'should return an empty array' do
      expect(provider.add_properties).to eq([])
    end
  end

  context "#create" do
    it "should execute zfs create" do
      provider.expects(:zfs).with(:create, name)

      provider.create
    end

    Puppet::Type.type(:zfs).validproperties.each do |prop|
      next if [:ensure, :volsize].include?(prop)
      it "should include property #{prop}" do
        resource[prop] = prop

        provider.expects(:zfs).with(:create, '-o', "#{prop}=#{prop}", name)

        provider.create
      end
    end

    it "should use -V for the volsize property" do
      resource[:volsize] = "10"
      provider.expects(:zfs).with(:create, '-V', "10", name)
      provider.create
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
      provider.expects(:zfs).with(:list, name)

      expect(provider).to be_exists
    end

    it "should return false if returned values don't match the name" do
      provider.expects(:zfs).with(:list, name).raises(Puppet::ExecutionFailure, "Failed")

      expect(provider).not_to be_exists
    end
  end

  describe "zfs properties" do
    [:aclinherit, :aclmode, :atime, :canmount, :checksum,
     :compression, :copies, :dedup, :devices, :exec, :logbias,
     :mountpoint, :nbmand,  :primarycache, :quota, :readonly,
     :recordsize, :refquota, :refreservation, :reservation,
     :secondarycache, :setuid, :shareiscsi, :sharenfs, :sharesmb,
     :snapdir, :version, :volsize, :vscan, :xattr].each do |prop|
      it "should get #{prop}" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', prop, name).returns("value\n")

        expect(provider.send(prop)).to eq('value')
      end

      it "should set #{prop}=value" do
        provider.expects(:zfs).with(:set, "#{prop}=value", name)

        provider.send("#{prop}=", "value")
      end
    end
  end
  describe "zoned" do
    context "on FreeBSD" do
      before do
        Facter.stubs(:value).with(:operatingsystem).returns("FreeBSD")
      end
      it "should get 'jailed' property" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', :jailed, name).returns("value\n")
        expect(provider.send("zoned")).to eq('value')
      end

      it "should set jalied=value" do
        provider.expects(:zfs).with(:set, "jailed=value", name)
        provider.send("zoned=", "value")
      end
    end

    context "when not running FreeBSD" do
      before do
        Facter.stubs(:value).with(:operatingsystem).returns("Solaris")
      end
      it "should get 'zoned' property" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', :zoned, name).returns("value\n")
        expect(provider.send("zoned")).to eq('value')
      end

      it "should set zoned=value" do
        provider.expects(:zfs).with(:set, "zoned=value", name)
        provider.send("zoned=", "value")
      end
    end
  end
  describe "acltype" do
    context "when available" do
      it "should get 'acltype' property" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', :acltype, name).returns("value\n")
        expect(provider.send("acltype")).to eq('value')
      end
      it "should set acltype=value" do
        provider.expects(:zfs).with(:set, "acltype=value", name)
        provider.send("acltype=", "value")
      end
    end

    context "when not available" do
      it "should get '-' for the acltype property" do
        provider.expects(:zfs).with(:get, '-H', '-o', 'value', :acltype, name).raises(RuntimeError, 'not valid')
        expect(provider.send("acltype")).to eq('-')
      end
      it "should not error out when trying to set acltype" do
        provider.expects(:zfs).with(:set, "acltype=value", name).raises(RuntimeError, 'not valid')
        expect{provider.send("acltype=", "value")}.to_not raise_error
      end
    end
  end
end
