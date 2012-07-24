#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

class PluginHandlerTester
  include Puppet::Configurer::PluginHandler
  attr_accessor :environment
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
    Puppet[:pluginsync] = true
    @pluginhandler.should be_download_plugins
  end

  it "should not download plugins when :pluginsync is false" do
    Puppet[:pluginsync] = false
    @pluginhandler.should_not be_download_plugins
  end

  it "should not download plugins when downloading is disabled" do
    Puppet::Configurer::Downloader.expects(:new).never
    @pluginhandler.expects(:download_plugins?).returns false
    @pluginhandler.download_plugins
  end

  it "should use an Agent Downloader, with the name, source, destination, ignore, and environment set correctly, to download plugins when downloading is enabled" do
    downloader = mock 'downloader'

    # This is needed in order to make sure we pass on windows
    plugindest = File.expand_path("/tmp/pdest")

    Puppet[:pluginsource] = "psource"
    Puppet[:plugindest] = plugindest
    Puppet[:pluginsignore] = "pignore"

    Puppet::Configurer::Downloader.expects(:new).with("plugin", plugindest, "psource", "pignore", "myenv").returns downloader

    downloader.expects(:evaluate).returns []

    @pluginhandler.environment = "myenv"
    @pluginhandler.expects(:download_plugins?).returns true
    @pluginhandler.download_plugins
  end
end
