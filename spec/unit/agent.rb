#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/agent'

describe Puppet::Agent do
    it "should have a start method" do
        Puppet::Agent.new.should respond_to(:start)
    end

    it "should be able to download a catalog" do
        Puppet::Agent.new.should respond_to(:download_catalog)
    end

    it "should set its name to the certname" do
        Puppet.settings.expects(:value).with(:certname).returns "myname"
        Puppet::Agent.new.name.should == "myname"
    end

    it "should be configurable to only run once" do
        Puppet::Agent.new(:onetime => true).should be_onetime
    end

    it "should be able to splay" do
        Puppet::Agent.new.should respond_to(:splay)
    end

    describe "when splaying" do
        before do
            @agent = Puppet::Agent.new
            @agent.stubs(:name).returns "foo"

            Puppet.settings.stubs(:value).with(:splaylimit).returns "1800"
            Puppet.settings.stubs(:value).with(:splaylimit).returns "1800"
        end

        it "should do nothing if splay is disabled" do
            Puppet.settings.expects(:value).with(:splay).returns false
            @agent.expects(:sleep).never
            @agent.splay
        end

        it "should sleep if splay is enabled" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.expects(:sleep)
            @agent.splay
        end

        it "should log when splay is enabled" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.stubs(:sleep)

            Puppet.expects(:info)

            @agent.splay
        end
    end

    it "should default to using splay time"

    it "should be able to ignore splay time"

    it "should be able to retrieve facts"

    describe "when running" do
        it "should download plugins"

        it "should download facts"

        it "should retrieve the facts and save them to the server"

        it "should retrieve the catalog"

        it "should apply the catalog"
    end

    describe "when retrieving the catalog" do
        before do
            @agent = Puppet::Agent.new
            @agent.stubs(:name).returns "me"

            @catalog = stub("catalog", :host_config= => true)
        end

        it "should use the Catalog class to find the catalog" do
            Puppet::Node::Catalog.expects(:find).with { |name, options| name == "me" }.returns @catalog

            @agent.catalog.should equal(@catalog)
        end

        it "should default to allowing use of the cache" do
            Puppet::Node::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.returns @catalog

            @agent.catalog
        end

        it "should ignore a cached catalog if configured to do so" do
            Puppet.settings.expects(:value).with(:ignorecache).returns true
            Puppet::Node::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns @catalog

            @agent.catalog
        end

        it "should mark the catalog as a host catalog" do
            @catalog.expects(:host_config=).with true
            Puppet::Node::Catalog.expects(:find).returns @catalog

            @agent.catalog
        end

        it "should fail if a catalog can not be retrieved" do
            Puppet::Node::Catalog.expects(:find).returns nil
            lambda { @agent.catalog }.should raise_error(RuntimeError)
        end
    end
end
