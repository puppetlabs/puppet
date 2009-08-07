#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/resource/catalog'

Puppet::Resource::Catalog.indirection.terminus(:compiler)

describe Puppet::Resource::Catalog::Compiler do
    before do
        @catalog = Puppet::Resource::Catalog.new

        @one = Puppet::Resource.new(:file, "/one")
        @one.virtual = true

        @two = Puppet::Resource.new(:file, "/two")
        @catalog.add_resource(@one, @two)
    end

    after { Puppet.settings.clear }

    it "should remove exported resources when filtering" do
        Puppet::Resource::Catalog.indirection.terminus.filter(@catalog).resources.should == [ @two.ref ]
    end

    it "should filter out exported resources when finding a catalog" do
        request = stub 'request', :name => "mynode"
        Puppet::Resource::Catalog.indirection.terminus.stubs(:extract_facts_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:node_from_request)
        Puppet::Resource::Catalog.indirection.terminus.stubs(:compile).returns(@catalog)

        Puppet::Resource::Catalog.find(request).resources.should == [ @two.ref ]
    end
end
