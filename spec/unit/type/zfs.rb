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
end
