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

    # PluginHandler#load_plugin has an extra-strong rescue clause
    # this mock is to make sure that we don't silently ignore errors
    Puppet.expects(:err).never
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

  it "should be able to load plugins" do
    @pluginhandler.should respond_to(:load_plugin)
  end

  it "should load each downloaded file" do
    FileTest.stubs(:exist?).returns true
    downloader = mock 'downloader'

    Puppet::Configurer::Downloader.expects(:new).returns downloader

    downloader.expects(:evaluate).returns %w{one two}

    @pluginhandler.expects(:download_plugins?).returns true

    @pluginhandler.expects(:load_plugin).with("one")
    @pluginhandler.expects(:load_plugin).with("two")

    @pluginhandler.download_plugins
  end

  it "should load plugins when asked to do so" do
    FileTest.stubs(:exist?).returns true
    @pluginhandler.expects(:load).with("foo")

    @pluginhandler.load_plugin("foo")
  end

  it "should not try to load files that don't exist" do
    FileTest.expects(:exist?).with("foo").returns false
    @pluginhandler.expects(:load).never

    @pluginhandler.load_plugin("foo")
  end

  it "should not try to load directories" do
    FileTest.stubs(:exist?).returns true
    FileTest.expects(:directory?).with("foo").returns true
    @pluginhandler.expects(:load).never

    @pluginhandler.load_plugin("foo")
  end

  it "should warn but not fail if loading a file raises an exception" do
    FileTest.stubs(:exist?).returns true
    @pluginhandler.expects(:load).with("foo").raises "eh"

    Puppet.expects(:err)
    @pluginhandler.load_plugin("foo")
  end

  it "should warn but not fail if loading a file raises a LoadError" do
    FileTest.stubs(:exist?).returns true
    @pluginhandler.expects(:load).with("foo").raises LoadError.new("eh")

    Puppet.expects(:err)
    @pluginhandler.load_plugin("foo")
  end
end
