#! /usr/bin/env ruby
require 'spec_helper'

zfs = Puppet::Type.type(:zfs)

describe zfs do
  properties = [:ensure, :mountpoint, :compression, :copies, :quota, :reservation, :sharenfs, :snapdir]

  properties.each do |property|
    it "should have a #{property} property" do
      expect(zfs.attrclass(property).ancestors).to be_include(Puppet::Property)
    end
  end

  parameters = [:name]

  parameters.each do |parameter|
    it "should have a #{parameter} parameter" do
      expect(zfs.attrclass(parameter).ancestors).to be_include(Puppet::Parameter)
    end
  end

  it "should autorequire the containing zfs and the zpool" do
    zfs_provider = mock "provider"
    zfs_provider.stubs(:name).returns(:zfs)
    zfs.stubs(:defaultprovider).returns(zfs_provider)

    zpool_provider = mock "provider"
    zpool_provider.stubs(:name).returns(:zpool)
    Puppet::Type.type(:zpool).stubs(:defaultprovider).returns(zpool_provider)

    foo_pool = Puppet::Type.type(:zpool).new(:name => "foo")

    foo_bar_zfs = Puppet::Type.type(:zfs).new(:name => "foo/bar")
    foo_bar_baz_zfs = Puppet::Type.type(:zfs).new(:name => "foo/bar/baz")
    foo_bar_baz_buz_zfs = Puppet::Type.type(:zfs).new(:name => "foo/bar/baz/buz")

    Puppet::Resource::Catalog.new :testing do |conf|
      [foo_pool, foo_bar_zfs, foo_bar_baz_zfs, foo_bar_baz_buz_zfs].each { |resource| conf.add_resource resource }
    end

    req = foo_bar_baz_buz_zfs.autorequire.collect { |edge| edge.source.ref }

    [foo_pool.ref, foo_bar_zfs.ref, foo_bar_baz_zfs.ref].each { |ref| expect(req.include?(ref)).to eq(true) }
  end
end
