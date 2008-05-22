#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-12.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/client/master'

describe Puppet::Network::Client::Master, " when retrieving the catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @master = mock 'master'
        @client = Puppet::Network::Client.master.new(
            :Master => @master
        )
        @facts = {"one" => "two", "three" => "four"}
    end

    it "should initialize the metadata store" do
        @client.class.stubs(:facts).returns(@facts)
        @client.expects(:dostorage)
        @master.stubs(:getconfig).returns(nil)
        @client.getconfig
    end

    it "should collect facts to use for catalog retrieval" do
        @client.stubs(:dostorage)
        @client.class.expects(:facts).returns(@facts)
        @master.stubs(:getconfig).returns(nil)
        @client.getconfig
    end

    it "should fail if no facts could be collected" do
        @client.stubs(:dostorage)
        @client.class.expects(:facts).returns({})
        @master.stubs(:getconfig).returns(nil)
        proc { @client.getconfig }.should raise_error(Puppet::Network::ClientError)
    end

    it "should retrieve plugins if :pluginsync is enabled" do
        file = "/path/to/cachefile"
        @client.stubs(:cachefile).returns(file)
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        Puppet.settings.expects(:value).with(:pluginsync).returns(true)
        @client.expects(:getplugins)
        @client.stubs(:get_actual_config).returns(nil)
        FileTest.stubs(:exist?).with(file).returns(true)
        @client.stubs(:use_cached_config).returns(true)
        @client.class.stubs(:facts).returns(@facts)
        @client.getconfig
    end

    it "should use the cached catalog if no catalog could be retrieved" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).raises(ArgumentError.new("whev"))
        @client.expects(:use_cached_config).with(true)
        @client.getconfig
    end

    it "should load the retrieved catalog using YAML" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        config = mock 'config'
        YAML.expects(:load).with("myconfig").returns(config)

        @client.stubs(:setclasses)

        config.stubs(:classes)
        config.stubs(:to_catalog).returns(config)
        config.stubs(:host_config=)
        config.stubs(:from_cache).returns(true)

        @client.getconfig
    end

    it "should use the cached catalog if the retrieved catalog cannot be converted from YAML" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        YAML.expects(:load).with("myconfig").raises(ArgumentError)

        @client.expects(:use_cached_config).with(true)

        @client.getconfig
    end

    it "should set the classes.txt file with the classes listed in the retrieved catalog" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        config = mock 'config'
        YAML.expects(:load).with("myconfig").returns(config)

        config.expects(:classes).returns(:myclasses)
        @client.expects(:setclasses).with(:myclasses)

        config.stubs(:to_catalog).returns(config)
        config.stubs(:host_config=)
        config.stubs(:from_cache).returns(true)

        @client.getconfig
    end

    it "should convert the retrieved catalog to a RAL catalog" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        yamlconfig = mock 'yaml config'
        YAML.stubs(:load).returns(yamlconfig)

        @client.stubs(:setclasses)

        config = mock 'config'

        yamlconfig.stubs(:classes)
        yamlconfig.expects(:to_catalog).returns(config)

        config.stubs(:host_config=)
        config.stubs(:from_cache).returns(true)

        @client.getconfig
    end

    it "should use the cached catalog if the retrieved catalog cannot be converted to a RAL catalog" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        yamlconfig = mock 'yaml config'
        YAML.stubs(:load).returns(yamlconfig)

        @client.stubs(:setclasses)

        config = mock 'config'

        yamlconfig.stubs(:classes)
        yamlconfig.expects(:to_catalog).raises(ArgumentError)

        @client.expects(:use_cached_config).with(true)

        @client.getconfig
    end

    it "should clear the failed catalog if using the cached catalog after failing to instantiate the retrieved catalog" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        yamlconfig = mock 'yaml config'
        YAML.stubs(:load).returns(yamlconfig)

        @client.stubs(:setclasses)

        config = mock 'config'

        yamlconfig.stubs(:classes)
        yamlconfig.stubs(:to_catalog).raises(ArgumentError)

        @client.stubs(:use_cached_config).with(true)

        @client.expects(:clear)

        @client.getconfig
    end

    it "should cache the retrieved yaml catalog if it is not from the cache and is valid" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        yamlconfig = mock 'yaml config'
        YAML.stubs(:load).returns(yamlconfig)

        @client.stubs(:setclasses)

        config = mock 'config'

        yamlconfig.stubs(:classes)
        yamlconfig.expects(:to_catalog).returns(config)

        config.stubs(:host_config=)

        config.expects(:from_cache).returns(false)

        @client.expects(:cache).with("myconfig")

        @client.getconfig
    end

    it "should mark the catalog as a host catalog" do
        @client.stubs(:dostorage)
        @client.class.stubs(:facts).returns(@facts)
        @master.stubs(:getconfig).returns("myconfig")

        yamlconfig = mock 'yaml config'
        YAML.stubs(:load).returns(yamlconfig)

        @client.stubs(:setclasses)

        config = mock 'config'

        yamlconfig.stubs(:classes)
        yamlconfig.expects(:to_catalog).returns(config)

        config.stubs(:from_cache).returns(true)

        config.expects(:host_config=).with(true)

        @client.getconfig
    end
end

describe Puppet::Network::Client::Master, " when using the cached catalog" do
    before do
        Puppet.settings.stubs(:use).returns(true)
        @master = mock 'master'
        @client = Puppet::Network::Client.master.new(
            :Master => @master
        )
        @facts = {"one" => "two", "three" => "four"}
    end

    it "should return do nothing and true if there is already an in-memory catalog" do
        @client.catalog = :whatever
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config.should be_true
        end
    end

    it "should return do nothing and false if it has been told there is a failure and :nocacheonfailure is enabled" do
        Puppet.settings.expects(:value).with(:usecacheonfailure).returns(false)
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config(true).should be_false
        end
    end

    it "should return false if no cached catalog can be found" do
        @client.expects(:retrievecache).returns(nil)
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config().should be_false
        end
    end

    it "should return false if the cached catalog cannot be instantiated" do
        YAML.expects(:load).raises(ArgumentError)
        @client.expects(:retrievecache).returns("whatever")
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config().should be_false
        end
    end

    it "should warn if the cached catalog cannot be instantiated" do
        YAML.stubs(:load).raises(ArgumentError)
        @client.stubs(:retrievecache).returns("whatever")
        Puppet.expects(:warning).with { |m| m.include?("Could not load cache") }
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config().should be_false
        end
    end

    it "should clear the client if the cached catalog cannot be instantiated" do
        YAML.stubs(:load).raises(ArgumentError)
        @client.stubs(:retrievecache).returns("whatever")
        @client.expects(:clear)
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config().should be_false
        end
    end

    it "should return true if the cached catalog can be instantiated" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @client.stubs(:retrievecache).returns("whatever")
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config().should be_true
        end
    end

    it "should set the catalog instance variable if the cached catalog can be instantiated" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @client.stubs(:retrievecache).returns("whatever")
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config()
        end

        @client.catalog.should equal(ral_config)
    end

    it "should mark the catalog as a host_config if valid" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.stubs(:from_cache=)
        ral_config.expects(:host_config=).with(true)
        config.expects(:to_catalog).returns(ral_config)

        @client.stubs(:retrievecache).returns("whatever")
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config()
        end

        @client.catalog.should equal(ral_config)
    end

    it "should mark the catalog as from the cache if valid" do
        config = mock 'config'
        YAML.stubs(:load).returns(config)

        ral_config = mock 'ral config'
        ral_config.expects(:from_cache=).with(true)
        ral_config.stubs(:host_config=)
        config.expects(:to_catalog).returns(ral_config)

        @client.stubs(:retrievecache).returns("whatever")
        Puppet::Network::Client::Master.publicize_methods :use_cached_config do
            @client.use_cached_config()
        end

        @client.catalog.should equal(ral_config)
    end
end
