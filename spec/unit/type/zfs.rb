#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

zpool = Puppet::Type.type(:zfs)

describe zpool do
    before do
        @provider = stub 'provider'
        @resource = stub 'resource', :resource => nil, :provider => @provider, :line => nil, :file => nil
    end

    properties = [:ensure, :mountpoint, :compression, :copies, :quota, :reservation, :sharenfs, :snapdir]

    properties.each do |property|
        it "should have a %s property" % property do
            zpool.attrclass(property).ancestors.should be_include(Puppet::Property)
        end
    end

    parameters = [:name]

    parameters.each do |parameter|
        it "should have a %s parameter" % parameter do
            zpool.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
        end
    end

    it "should autorequire the containing zfss and the zpool" do
            #this is a little funky because the autorequire depends on a property with a feature
            foo_pool = Puppet.type(:zpool).create(:name => "foo")

            foo_bar_zfs = Puppet.type(:zfs).create(:name => "foo/bar")
            foo_bar_baz_zfs = Puppet.type(:zfs).create(:name => "foo/bar/baz")
            foo_bar_baz_buz_zfs = Puppet.type(:zfs).create(:name => "foo/bar/baz/buz")

            config = Puppet::Node::Catalog.new :testing do |conf|
                [foo_pool, foo_bar_zfs, foo_bar_baz_zfs, foo_bar_baz_buz_zfs].each { |resource| conf.add_resource resource }
            end

            req = foo_bar_baz_buz_zfs.autorequire.collect { |edge| edge.source.ref }

            [foo_pool.ref, foo_bar_zfs.ref, foo_bar_baz_zfs.ref].each { |ref| req.include?(ref).should == true }
    end
end
