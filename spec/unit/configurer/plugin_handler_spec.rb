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
    environment = Puppet::Node::Environment.create(:myenv, [])
    Puppet.features.stubs(:external_facts?).returns(:true)
    plugindest = File.expand_path("/tmp/pdest")
    Puppet[:pluginsource] = "psource"
    Puppet[:plugindest] = plugindest
    Puppet[:pluginsignore] = "pignore"
    Puppet[:pluginfactsource] = "psource"
    Puppet[:pluginfactdest] = plugindest

    downloader = mock 'downloader'
    Puppet::Configurer::Downloader.expects(:new).with("pluginfacts", plugindest, "psource", "pignore", environment).returns downloader
    Puppet::Configurer::Downloader.expects(:new).with("plugin", plugindest, "psource", "pignore", environment).returns downloader

    downloader.stubs(:evaluate).returns([])
    downloader.expects(:evaluate).twice

    @pluginhandler.download_plugins(environment)
  end
end
