#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

class PluginHandlerTester
  include Puppet::Configurer::PluginHandler
end

describe Puppet::Configurer::PluginHandler do
  before do
    @pluginhandler = PluginHandlerTester.new
  end

  it "should have a method for downloading plugins" do
    @pluginhandler.should respond_to(:download_plugins)
  end

  it "should have a boolean method for determining whether plugins should be downloaded" do
    @pluginhandler.should respond_to(:download_plugins?)
  end

  it "should download plugins when :pluginsync is true" do
    Puppet.settings.expects(:value).with(:pluginsync).returns true
    @pluginhandler.should be_download_plugins
  end

  it "should not download plugins when :pluginsync is false" do
    Puppet.settings.expects(:value).with(:pluginsync).returns false
    @pluginhandler.should_not be_download_plugins
  end

  it "should not download plugins when downloading is disabled" do
    Puppet::Configurer::Downloader.expects(:new).never
    @pluginhandler.expects(:download_plugins?).returns false
    @pluginhandler.download_plugins
  end

  it "should use an Agent Downloader, with the name, source, destination, and ignore set correctly, to download plugins when downloading is enabled" do
    downloader = mock 'downloader'

    Puppet.settings.expects(:value).with(:pluginsource).returns "psource"
    Puppet.settings.expects(:value).with(:plugindest).returns "pdest"
    Puppet.settings.expects(:value).with(:pluginsignore).returns "pignore"

    Puppet::Configurer::Downloader.expects(:new).with("plugin", "pdest", "psource", "pignore").returns downloader

    downloader.expects(:evaluate).returns []

    @pluginhandler.expects(:download_plugins?).returns true
    @pluginhandler.download_plugins
  end
end
