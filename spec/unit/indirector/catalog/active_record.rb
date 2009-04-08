#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/catalog/active_record'

describe Puppet::Node::Catalog::ActiveRecord do
    confine "Missing Rails" => Puppet.features.rails?

    before do
        Puppet.features.stubs(:rails?).returns true
        @terminus = Puppet::Node::Catalog::ActiveRecord.new
    end

    it "should be a subclass of the ActiveRecord terminus class" do
        Puppet::Node::Catalog::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
    end

    it "should use Puppet::Rails::Host as its ActiveRecord model" do
        Puppet::Node::Catalog::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
    end

    describe "when finding an instance" do
        before do
            @request = stub 'request', :key => "foo", :options => {:cache_integration_hack => true}
        end

        # This hack is here because we don't want to look in the db unless we actually want
        # to look in the db, but our indirection architecture in 0.24.x isn't flexible
        # enough to tune that via configuration.
        it "should return nil unless ':cache_integration_hack' is set to true" do
            @request.options[:cache_integration_hack] = false
            Puppet::Rails::Host.expects(:find_by_name).never
            @terminus.find(@request).should be_nil
        end

        it "should use the Hosts ActiveRecord class to find the host" do
            Puppet::Rails::Host.expects(:find_by_name).with { |key, args| key == "foo" }
            @terminus.find(@request)
        end

        it "should return nil if no host instance can be found" do
            Puppet::Rails::Host.expects(:find_by_name).returns nil

            @terminus.find(@request).should be_nil
        end

        it "should return a catalog with the same name as the host if the host can be found" do
            host = stub 'host', :name => "foo", :resources => []
            Puppet::Rails::Host.expects(:find_by_name).returns host

            result = @terminus.find(@request)
            result.should be_instance_of(Puppet::Node::Catalog)
            result.name.should == "foo"
        end
        
        it "should set each of the host's resources as a transportable resource within the catalog" do
            host = stub 'host', :name => "foo"
            Puppet::Rails::Host.expects(:find_by_name).returns host

            res1 = mock 'res1', :to_transportable => "trans_res1"
            res2 = mock 'res2', :to_transportable => "trans_res2"

            host.expects(:resources).returns [res1, res2]

            catalog = stub 'catalog'
            Puppet::Node::Catalog.expects(:new).returns catalog

            catalog.expects(:add_resource).with "trans_res1"
            catalog.expects(:add_resource).with "trans_res2"

            @terminus.find(@request)
        end
    end

    describe "when saving an instance" do
        before do
            @host = stub 'host', :name => "foo", :save => nil, :merge_resources => nil, :last_compile= => nil
            Puppet::Rails::Host.stubs(:find_by_name).returns @host
            @catalog = Puppet::Node::Catalog.new("foo")
            @request = stub 'request', :key => "foo", :instance => @catalog
        end

        it "should find the Rails host with the same name" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

            @terminus.save(@request)
        end

        it "should create a new Rails host if none can be found" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns nil

            Puppet::Rails::Host.expects(:create).with(:name => "foo").returns @host

            @terminus.save(@request)
        end

        it "should set the catalog vertices as resources on the Rails host instance" do
            @catalog.expects(:vertices).returns "foo"
            @host.expects(:merge_resources).with("foo")

            @terminus.save(@request)
        end

        it "should set the last compile time on the host" do
            now = Time.now
            Time.expects(:now).returns now
            @host.expects(:last_compile=).with now

            @terminus.save(@request)
        end

        it "should save the Rails host instance" do
            @host.expects(:save)

            @terminus.save(@request)
        end
    end
end
