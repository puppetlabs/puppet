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

  it "downloads plugins, facts, and locales" do
    plugin_downloader = stub('plugin-downloader', :evaluate => [])
    facts_downloader = stub('facts-downloader', :evaluate => [])
    locales_downloader = stub('locales-downloader', :evaluate => [])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)
    factory.expects(:create_locales_downloader).returns(locales_downloader)

    pluginhandler.download_plugins(environment)
  end

  it "returns downloaded plugin, fact, and locale filenames" do
    plugin_downloader = stub('plugin-downloader', :evaluate => %w[/a])
    facts_downloader = stub('facts-downloader', :evaluate => %w[/b])
    locales_downloader = stub('locales-downloader', :evaluate => %w[/c])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)
    factory.expects(:create_locales_downloader).returns(locales_downloader)

    expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b /c])
  end
end
