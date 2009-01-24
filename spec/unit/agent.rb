#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-12.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/agent'

describe Puppet::Agent do
    it "should include the Plugin Handler module" do
        Puppet::Agent.ancestors.should be_include(Puppet::Agent::PluginHandler)
    end

    it "should include the Fact Handler module" do
        Puppet::Agent.ancestors.should be_include(Puppet::Agent::FactHandler)
    end

    it "should include the Locker module" do
        Puppet::Agent.ancestors.should be_include(Puppet::Agent::Locker)
    end
end

describe Puppet::Agent, "when executing a catalog run" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Agent.new
        @agent.stubs(:splay)
        @agent.stubs(:lock).yields.then.returns true
    end

    it "should splay" do
        Puppet::Util.sync(:puppetrun).stubs(:synchronize)
        @agent.expects(:splay)
        @agent.run
    end

    it "should use a global mutex to make sure no other thread is executing the catalog" do
        sync = mock 'sync'
        Puppet::Util.expects(:sync).with(:puppetrun).returns sync

        sync.expects(:synchronize)

        @agent.expects(:retrieve_config).never # i.e., if we don't yield, we don't retrieve the config
        @agent.run
    end

    it "should retrieve the catalog if a lock is attained" do
        @agent.expects(:lock).yields.then.returns true

        @agent.expects(:retrieve_catalog)

        @agent.run
    end

    it "should log and do nothing if the lock cannot be acquired" do
        @agent.expects(:lock).returns false

        @agent.expects(:retrieve_catalog).never

        Puppet.expects(:notice)

        @agent.run
    end

    it "should retrieve the catalog" do
        @agent.expects(:retrieve_catalog)

        @agent.run
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
        @agent.expects(:retrieve_catalog).returns nil

        Puppet.expects(:err)

        @agent.run
    end

    it "should apply the catalog with all options to :run" do
        catalog = stub 'catalog', :retrieval_duration= => nil
        @agent.expects(:retrieve_catalog).returns catalog

        catalog.expects(:apply).with(:one => true)
        @agent.run :one => true
    end
    
    it "should benchmark how long it takes to apply the catalog" do
        @agent.expects(:benchmark).with(:notice, "Finished catalog run")

        catalog = stub 'catalog', :retrieval_duration= => nil
        @agent.expects(:retrieve_catalog).returns catalog

        catalog.expects(:apply).never # because we're not yielding
        @agent.run
    end

    it "should HUP itself if it should be restarted" do
        catalog = stub 'catalog', :retrieval_duration= => nil, :apply => nil
        @agent.expects(:retrieve_catalog).returns catalog

        Process.expects(:kill).with(:HUP, $$)

        @agent.expects(:restart?).returns true

        @agent.run
    end

    it "should not HUP itself if it should not be restarted" do
        catalog = stub 'catalog', :retrieval_duration= => nil, :apply => nil
        @agent.expects(:retrieve_catalog).returns catalog

        Process.expects(:kill).never

        @agent.expects(:restart?).returns false

        @agent.run
    end
end

describe Puppet::Agent, "when retrieving a catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Agent.new

        @catalog = Puppet::Resource::Catalog.new

        @agent.stubs(:convert_catalog).returns @catalog
    end

    it "should use the Catalog class to get its catalog" do
        Puppet::Resource::Catalog.expects(:find).returns @catalog

        @agent.retrieve_catalog
    end

    it "should use its Facter name to retrieve the catalog" do
        Facter.stubs(:value).returns "eh"
        Facter.expects(:value).with("hostname").returns "myhost"
        Puppet::Resource::Catalog.expects(:find).with { |name, options| name == "myhost" }.returns @catalog

        @agent.retrieve_catalog
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns nil
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns @catalog
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.never

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.raises "eh"
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns nil
        Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.returns nil

        @agent.retrieve_catalog.should be_nil
    end

    it "should convert the catalog before returning" do
        Puppet::Resource::Catalog.stubs(:find).returns @catalog

        @agent.expects(:convert_catalog).with { |cat, dur| cat == @catalog }.returns "converted catalog"
        @agent.retrieve_catalog.should == "converted catalog"
    end

    it "should return nil if there is an error while retrieving the catalog" do
        Puppet::Resource::Catalog.expects(:find).raises "eh"

        @agent.retrieve_catalog.should be_nil
    end
end

describe Puppet::Agent, "when converting the catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Agent.new

        @catalog = Puppet::Resource::Catalog.new
        @oldcatalog = stub 'old_catalog', :to_ral => @catalog
    end

    it "should convert the catalog to a RAL-formed catalog" do
        @oldcatalog.expects(:to_ral).returns @catalog

        @agent.convert_catalog(@oldcatalog, 10).should equal(@catalog)
    end

    it "should record the passed retrieval time with the RAL catalog" do
        @catalog.expects(:retrieval_duration=).with 10

        @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should write the RAL catalog's class file" do
        @catalog.expects(:write_class_file)

        @agent.convert_catalog(@oldcatalog, 10)
    end

    it "should mark the RAL catalog as a host catalog" do
        @catalog.expects(:host_config=).with true

        @agent.convert_catalog(@oldcatalog, 10)
    end
end

describe Puppet::Agent, "when preparing for a run" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Agent.new
        @agent.stubs(:dostorage)
        @agent.stubs(:upload_facts)
        @facts = {"one" => "two", "three" => "four"}
    end

    it "should initialize the metadata store" do
        @agent.class.stubs(:facts).returns(@facts)
        @agent.expects(:dostorage)
        @agent.prepare
    end

    it "should download fact plugins" do
        @agent.stubs(:dostorage)
        @agent.expects(:download_fact_plugins)

        @agent.prepare
    end

    it "should download plugins" do
        @agent.stubs(:dostorage)
        @agent.expects(:download_plugins)

        @agent.prepare
    end

    it "should upload facts to use for catalog retrieval" do
        @agent.stubs(:dostorage)
        @agent.expects(:upload_facts)
        @agent.prepare
    end
end
