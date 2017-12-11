#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

describe Puppet::Configurer::PluginHandler do
  let(:factory)       { Puppet::Configurer::DownloaderFactory.new }
  let(:pluginhandler) { Puppet::Configurer::PluginHandler.new(factory) }
  let(:environment)   { Puppet::Node::Environment.create(:myenv, []) }


  context "server agent version is 5.3.4" do

    before :each do
      # PluginHandler#load_plugin has an extra-strong rescue clause
      # this mock is to make sure that we don't silently ignore errors
      Puppet.expects(:err).never
      # Server_agent version needs to be at 5.3.4 in order to mount locales
      Puppet.push_context({:server_agent_version => "5.3.4"})
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

  context "server agent version is 5.3.3" do

    before :each do
      # PluginHandler#load_plugin has an extra-strong rescue clause
      # this mock is to make sure that we don't silently ignore errors
      Puppet.expects(:err).never
      # Server_agent version needs to be at 5.3.4 in order to mount locales
      Puppet.push_context({:server_agent_version => "5.3.3"})
    end

    it "returns downloaded plugin, fact, but not locale filenames" do
      plugin_downloader = stub('plugin-downloader', :evaluate => %w[/a])
      facts_downloader = stub('facts-downloader', :evaluate => %w[/b])

      factory.expects(:create_plugin_downloader).returns(plugin_downloader)
      factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)
      factory.expects(:create_locales_downloader).never

      expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b])
    end
  end

  context "blank server agent version" do
    before :each do
      # PluginHandler#load_plugin has an extra-strong rescue clause
      # this mock is to make sure that we don't silently ignore errors
      Puppet.expects(:err).never
      # Server_agent version needs to be at 5.3.4 in order to mount locales
      # A blank version will default to 0.0
      Puppet.push_context({:server_agent_version => ""})
    end

    it "returns downloaded plugin, fact, but not locale filenames" do
      plugin_downloader = stub('plugin-downloader', :evaluate => %w[/a])
      facts_downloader = stub('facts-downloader', :evaluate => %w[/b])

      factory.expects(:create_plugin_downloader).returns(plugin_downloader)
      factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)
      factory.expects(:create_locales_downloader).never

      expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b])
    end

  end
end
