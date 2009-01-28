#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/fact_handler'

class FactHandlerTester
    include Puppet::Configurer::FactHandler
end

describe Puppet::Configurer::FactHandler do
    before do
        @facthandler = FactHandlerTester.new
    end

    it "should have a method for downloading fact plugins" do
        @facthandler.should respond_to(:download_fact_plugins)
    end

    it "should have a boolean method for determining whether fact plugins should be downloaded" do
        @facthandler.should respond_to(:download_fact_plugins?)
    end

    it "should download fact plugins when :factsync is true" do
        Puppet.settings.expects(:value).with(:factsync).returns true
        @facthandler.should be_download_fact_plugins
    end

    it "should not download fact plugins when :factsync is false" do
        Puppet.settings.expects(:value).with(:factsync).returns false
        @facthandler.should_not be_download_fact_plugins
    end

    it "should not download fact plugins when downloading is disabled" do
        Puppet::Configurer::Downloader.expects(:new).never
        @facthandler.expects(:download_fact_plugins?).returns false
        @facthandler.download_fact_plugins
    end

    it "should use an Agent Downloader, with the name, source, destination, and ignore set correctly, to download fact plugins when downloading is enabled" do
        downloader = mock 'downloader'

        Puppet.settings.expects(:value).with(:factsource).returns "fsource"
        Puppet.settings.expects(:value).with(:factdest).returns "fdest"
        Puppet.settings.expects(:value).with(:factsignore).returns "fignore"

        Puppet::Configurer::Downloader.expects(:new).with("fact", "fsource", "fdest", "fignore").returns downloader

        downloader.expects(:evaluate)

        @facthandler.expects(:download_fact_plugins?).returns true
        @facthandler.download_fact_plugins
    end

    it "should have a method for uploading facts" do
        @facthandler.should respond_to(:upload_facts)
    end

    it "should reload Facter and find local facts when asked to upload facts" do
        @facthandler.expects(:reload_facter)

        Puppet.settings.expects(:value).with(:certname).returns "myhost"
        Puppet::Node::Facts.expects(:find).with("myhost")

        @facthandler.upload_facts
    end

    describe "when reloading Facter" do
        before do
            Facter.stubs(:clear)
            Facter.stubs(:load)
            Facter.stubs(:loadfacts)
        end

        it "should clear Facter" do
            Facter.expects(:clear)
            @facthandler.reload_facter
        end

        it "should load all Facter facts" do
            Facter.expects(:loadfacts)
            @facthandler.reload_facter
        end

        it "should use the Facter terminus load all Puppet Fact plugins" do
            Puppet::Node::Facts::Facter.expects(:load_fact_plugins)
            @facthandler.reload_facter
        end
    end
end
