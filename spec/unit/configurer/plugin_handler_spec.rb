#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

describe Puppet::Configurer::PluginHandler do
  let(:factory)       { Puppet::Configurer::DownloaderFactory.new }
  let(:pluginhandler) { Puppet::Configurer::PluginHandler.new(factory) }
  let(:environment)   { Puppet::Node::Environment.create(:myenv, []) }

  before :each do
    # PluginHandler#load_plugin has an extra-strong rescue clause
    # this mock is to make sure that we don't silently ignore errors
    Puppet.expects(:err).never
  end

  it "downloads plugins and facts" do
    Puppet.features.stubs(:external_facts?).returns(true)

    plugin_downloader = stub('plugin-downloader', :evaluate => [])
    facts_downloader = stub('facts-downloader', :evaluate => [])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)

    pluginhandler.download_plugins(environment)
  end

  it "skips facts if not enabled" do
    Puppet.features.stubs(:external_facts?).returns(false)

    plugin_downloader = stub('plugin-downloader', :evaluate => [])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).never

    pluginhandler.download_plugins(environment)
  end
end
