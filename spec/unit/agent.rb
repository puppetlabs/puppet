#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/agent'

describe Puppet::Agent do
    it "should be able to provide a timeout value" do
        Puppet::Agent.should respond_to(:timeout)
    end

    it "should use the configtimeout, converted to an integer, as its timeout" do
        Puppet.settings.expects(:value).with(:configtimeout).returns "50"
        Puppet::Agent.timeout.should == 50
    end

    describe "when managing the lockfile" do
        after do
            Puppet::Agent.instance_variable_set("@lockfile", nil)
        end

        it "should use Pidlock to manage the lock file itself" do
            Puppet::Agent.instance_variable_set("@lockfile", nil)

            Puppet.settings.expects(:value).with(:puppetdlockfile).returns "/lock/file"
            Puppet::Util::Pidlock.expects(:new).with("/lock/file").returns "mylock"

            Puppet::Agent.lockfile.should == "mylock"
        end

        it "should always reuse the same lock file instance" do
            Puppet::Agent.lockfile.should equal(Puppet::Agent.lockfile)
        end

        it "should have a class method for disabling the agent" do
            Puppet::Agent.should respond_to(:disable)
        end

        it "should have a class method for enabling the agent" do
            Puppet::Agent.should respond_to(:enable)
        end

        it "should use the lockfile to disable the agent anonymously" do
            Puppet::Agent.lockfile.expects(:lock).with(:anonymous => true)
            Puppet::Agent.disable
        end

        it "should use the lockfile to enable the agent anonymously" do
            Puppet::Agent.lockfile.expects(:unlock).with(:anonymous => true)
            Puppet::Agent.enable
        end

        it "should have a class method for determining whether the agent is enabled" do
            Puppet::Agent.should respond_to(:enabled?)
        end

        it "should consider the agent enabled if the lockfile is not locked" do
            Puppet::Agent.lockfile.expects(:locked?).returns false
            Puppet::Agent.should be_enabled
        end

        it "should consider the agent disabled if the lockfile is locked" do
            Puppet::Agent.lockfile.expects(:locked?).returns true
            Puppet::Agent.should_not be_enabled
        end
    end

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
            Puppet.settings.stubs(:value).with(:splay).returns true
        end

        it "should sleep if it has not previously splayed" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.expects(:sleep)
            @agent.splay
        end
        
        it "should do nothing if it has already splayed" do
            @agent.expects(:sleep).once
            @agent.splay
            @agent.splay
        end

        it "should log if it is sleeping" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.stubs(:sleep)

            Puppet.expects(:info)

            @agent.splay
        end
    end

    describe "when running" do
        before do
            @agent = Puppet::Agent.new
            [:upload_facts, :download_catalog, :apply].each { |m| @agent.stubs(m) }
        end

        it "should splay if splay is enabled" do
            @agent.expects(:splay?).returns true
            @agent.expects(:splay)
            @agent.run
        end

        it "should not splay if splay is disabled" do
            @agent.expects(:splay?).returns false
            @agent.expects(:splay).never
            @agent.run
        end

        it "should download plugins if plugin downloading is enabled" do
            @agent.expects(:download_plugins?).returns true
            @agent.expects(:download_plugins)
            @agent.run
        end

        it "should not download plugins if plugin downloading is disabled" do
            @agent.expects(:download_plugins?).returns false
            @agent.expects(:download_plugins).never
            @agent.run
        end

        it "should download facts if fact downloading is enabled" do
            @agent.expects(:download_facts?).returns true
            @agent.expects(:download_facts)
            @agent.run
        end

        it "should not download facts if fact downloading is disabled" do
            @agent.expects(:download_facts?).returns false
            @agent.expects(:download_facts).never
            @agent.run
        end

        it "should retrieve the facts and save them to the server" do
            @agent.expects(:upload_facts)
            @agent.run
        end

        it "should retrieve the catalog" do
            @agent.expects(:download_catalog)
            @agent.run
        end

        it "should apply the catalog" do
            catalog = mock("catalog")
            @agent.expects(:download_catalog).returns catalog
            @agent.expects(:apply).with(catalog)
            @agent.run
        end
    end

    describe "when downloading plugins" do
        before do
            @agent = Puppet::Agent.new
            @downloader = stub 'downloader', :evaluate
        end

        it "should download plugins if the :pluginsync setting is true" do
            Puppet.settings.expects(:value).with(:pluginsync).returns true
            @agent.should be_download_plugins
        end

        it "should not download plugins if the :pluginsync setting is false" do
            Puppet.settings.expects(:value).with(:pluginsync).returns false
            @agent.should_not be_download_plugins
        end

        it "should use a Downloader instance with its name set to 'plugin' and the pluginsource, plugindest, and pluginsignore settings" do
            Puppet.settings.expects(:value).with(:pluginsource).returns "plugsource"
            Puppet.settings.expects(:value).with(:plugindest).returns "plugdest"
            Puppet.settings.expects(:value).with(:pluginsignore).returns "plugig"
            Puppet::Agent::Downloader.expects(:new).with("plugin", "plugsource", "plugdest", "plugig").returns @downloader
            @downloader.expects(:evaluate)
            @agent.download_plugins
        end
    end

    describe "when downloading facts" do
        before do
            @agent = Puppet::Agent.new
            @downloader = stub 'downloader', :evaluate
        end

        it "should download facts if the :factsync setting is true" do
            Puppet.settings.expects(:value).with(:factsync).returns true
            @agent.should be_download_facts
        end

        it "should not download facts if the :factsync setting is false" do
            Puppet.settings.expects(:value).with(:factsync).returns false
            @agent.should_not be_download_facts
        end

        it "should use a Downloader instance with its name set to 'facts' and the factssource, factsdest, and factsignore settings" do
            Puppet.settings.expects(:value).with(:factsource).returns "factsource"
            Puppet.settings.expects(:value).with(:factdest).returns "factdest"
            Puppet.settings.expects(:value).with(:factsignore).returns "factig"
            Puppet::Agent::Downloader.expects(:new).with("fact", "factsource", "factdest", "factig").returns @downloader
            @downloader.expects(:evaluate)
            @agent.download_facts
        end
    end

    describe "when uploading facts" do
        it "should just retrieve the facts for the current host" do
            @agent = Puppet::Agent.new

            Puppet::Node::Facts.expects(:find).with(Puppet[:certname])
            @agent.upload_facts
        end
    end

    describe "when retrieving the catalog" do
        before do
            @agent = Puppet::Agent.new
            @agent.stubs(:name).returns "me"

            @catalog = stub("catalog", :host_config= => true)
        end

        it "should use the Catalog class to find the catalog" do
            Puppet::Resource::Catalog.expects(:find).with { |name, options| name == "me" }.returns @catalog

            @agent.download_catalog.should equal(@catalog)
        end

        it "should default to allowing use of the cache" do
            Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == true }.returns @catalog

            @agent.download_catalog
        end

        it "should ignore a cached catalog if configured to do so" do
            Puppet.settings.expects(:value).with(:ignorecache).returns true
            Puppet::Resource::Catalog.expects(:find).with { |name, options| options[:use_cache] == false }.returns @catalog

            @agent.download_catalog
        end

        it "should mark the catalog as a host catalog" do
            @catalog.expects(:host_config=).with true
            Puppet::Resource::Catalog.expects(:find).returns @catalog

            @agent.download_catalog
        end

        it "should fail if a catalog can not be retrieved" do
            Puppet::Resource::Catalog.expects(:find).returns nil
            lambda { @agent.download_catalog }.should raise_error(RuntimeError)
        end
    end
end
