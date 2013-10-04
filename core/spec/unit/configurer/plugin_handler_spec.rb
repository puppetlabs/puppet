#! /usr/bin/env ruby
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
    @pluginhandler.download_plugins
  end
end
