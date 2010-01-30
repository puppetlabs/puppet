#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/resource/catalog'

Puppet::Resource::Catalog.indirection.terminus(:compiler)

describe Puppet::Resource::Catalog::Compiler do
    before do
        Facter.stubs(:value).returns "something"
        @catalog = Puppet::Resource::Catalog.new

        @one = Puppet::Resource.new(:file, "/one")

        @two = Puppet::Resource.new(:file, "/two")
        @catalog.add_resource(@one, @two)
    end

    after { Puppet.settings.clear }

    it "should remove virtual resources when filtering" do
        @one.virtual = true
        Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resources.should == [ @two.ref ]
    end

    it "should not remove exported resources when filtering" do
        @one.exported = true
        Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resources.sort.should == [ @one.ref, @two.ref ]
    end

    it "should remove virtual exported resources when filtering" do
        @one.exported = true
        @one.virtual = true
        Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resources.should == [ @two.ref ]
    end

    it "should filter out virtual resources when finding a catalog" do
        @one.virtual = true
        request = stub 'request', :name => "mynode"
        Puppet::Resource::Catalog.indirection.terminus.stubs(:extract_facts_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:node_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:compile).returns(@catalog)

        Puppet::Resource::Catalog.find(request).resources.should == [ @two.ref ]
    end

    it "should not filter out exported resources when finding a catalog" do
        @one.exported = true
        request = stub 'request', :name => "mynode"
        Puppet::Resource::Catalog.indirection.terminus.stubs(:extract_facts_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:node_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:compile).returns(@catalog)

        Puppet::Resource::Catalog.find(request).resources.sort.should == [ @one.ref, @two.ref ]
    end

    it "should filter out virtual exported resources when finding a catalog" do
        @one.exported = true
        @one.virtual = true
        request = stub 'request', :name => "mynode"
        Puppet::Resource::Catalog.indirection.terminus.stubs(:extract_facts_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:node_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:compile).returns(@catalog)

        Puppet::Resource::Catalog.find(request).resources.should == [ @two.ref ]
    end
end
