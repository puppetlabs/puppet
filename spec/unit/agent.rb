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
    end

    it "should use the Catalog class to get its catalog" do
        Puppet::Resource::Catalog.expects(:get).returns @catalog

        @agent.retrieve_catalog
    end

    it "should use its Facter name to retrieve the catalog" do
        Facter.stubs(:value).returns "eh"
        Facter.expects(:value).with("hostname").returns "myhost"
        Puppet::Resource::Catalog.expects(:get).with { |name, options| name == "myhost" }.returns @catalog

        @agent.retrieve_catalog
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == false }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == false }.returns nil
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == false }.raises "eh"
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == true }.returns @catalog

        @agent.retrieve_catalog.should == @catalog
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == false }.returns nil
        Puppet::Resource::Catalog.expects(:get).with { |name, options| options[:use_cache] == true }.returns nil

        @agent.retrieve_catalog.should be_nil
    end

    it "should record the retrieval time with the catalog" do
        @agent.expects(:thinmark).yields.then.returns 10

        Puppet::Resource::Catalog.expects(:get).returns @catalog

        @catalog.expects(:retrieval_duration=).with 10

        @agent.retrieve_catalog
    end

    it "should write the catalog's class file" do
        @catalog.expects(:write_class_file)

        Puppet::Resource::Catalog.expects(:get).returns @catalog

        @agent.retrieve_catalog
    end

    it "should mark the catalog as a host catalog" do
        @catalog.expects(:host_config=).with true

        Puppet::Resource::Catalog.expects(:get).returns @catalog

        @agent.retrieve_catalog
    end

    it "should return nil if there is an error while retrieving the catalog" do
        Puppet::Resource::Catalog.expects(:get).raises "eh"

        @agent.retrieve_catalog.should be_nil
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

describe Puppet::Agent, " when using the cached catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @agent = Puppet::Agent.new
        @facts = {"one" => "two", "three" => "four"}
    end

    it "should return do nothing and true if there is already an in-memory catalog" do
        @agent.catalog = :whatever
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config.should be_true
        end
    end

    it "should return do nothing and false if it has been told there is a failure and :nocacheonfailure is enabled" do
        Puppet.settings.expects(:value).with(:usecacheonfailure).returns(false)
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config(true).should be_false
        end
    end

    it "should return false if no cached catalog can be found" do
        @agent.expects(:retrievecache).returns(nil)
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config().should be_false
        end
    end

    it "should return false if the cached catalog cannot be instantiated" do
        YAML.expects(:load).raises(ArgumentError)
        @agent.expects(:retrievecache).returns("whatever")
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config().should be_false
        end
    end

    it "should warn if the cached catalog cannot be instantiated" do
        YAML.stubs(:load).raises(ArgumentError)
        @agent.stubs(:retrievecache).returns("whatever")
        Puppet.expects(:warning).with { |m| m.include?("Could not load cache") }
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config().should be_false
        end
    end

    it "should clear the client if the cached catalog cannot be instantiated" do
        YAML.stubs(:load).raises(ArgumentError)
        @agent.stubs(:retrievecache).returns("whatever")
        @agent.expects(:clear)
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config().should be_false
        end
    end

    it "should return true if the cached catalog can be instantiated" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @agent.stubs(:retrievecache).returns("whatever")
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config().should be_true
        end
    end

    it "should set the catalog instance variable if the cached catalog can be instantiated" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @agent.stubs(:retrievecache).returns("whatever")
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config()
        end

        @agent.catalog.should equal(ral_config)
    end

    it "should mark the catalog as a host_config if valid" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.expects(:host_config=).with(true)
        config.expects(:to_catalog).returns(ral_config)

        @agent.stubs(:retrievecache).returns("whatever")
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config()
        end

        @agent.catalog.should equal(ral_config)
    end

    it "should mark the catalog as from the cache if valid" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.expects(:from_cache=).with(true)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @agent.stubs(:retrievecache).returns("whatever")
        Puppet::Agent.publicize_methods :use_cached_config do
            @agent.use_cached_config()
        end

        @agent.catalog.should equal(ral_config)
    end

    describe "when calling splay" do
        it "should do nothing if splay is not enabled" do
            Puppet.stubs(:[]).with(:splay).returns(false)
            @agent.expects(:rand).never
            @agent.send(:splay)
        end

        describe "when splay is enabled" do
            before do
                Puppet.stubs(:[]).with(:splay).returns(true)
                Puppet.stubs(:[]).with(:splaylimit).returns(42)
            end

            it "should sleep for a random time plus 1" do
                @agent.expects(:rand).with(43).returns(43)
                @agent.expects(:sleep).with(43)
                @agent.send(:splay)
            end

            it "should inform that it is splayed" do
                @agent.stubs(:rand).with(43).returns(43)
                @agent.stubs(:sleep).with(43)
                Puppet.expects(:info)
                @agent.send(:splay)
            end

            it "should set splay = true" do
                @agent.stubs(:rand).returns(43)
                @agent.stubs(:sleep)
                @agent.send(:splay)
                @agent.send(:splayed?).should == true
            end

            it "should do nothing if already splayed" do
                @agent.stubs(:rand).returns(43).at_most_once
                @agent.stubs(:sleep).at_most_once
                @agent.send(:splay)
                @agent.send(:splay)
            end
        end 
    end
end
