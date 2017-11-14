#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

describe Puppet::Configurer::PluginHandler do
  let(:pluginhandler) { Puppet::Configurer::PluginHandler.new() }
  let(:environment)   { Puppet::Node::Environment.create(:myenv, []) }

  before :each do
    # PluginHandler#load_plugin has an extra-strong rescue clause
    # this mock is to make sure that we don't silently ignore errors
    Puppet.expects(:err).never
  end

  it "downloads plugins, facts, and locales" do
    Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(3).returns([])

    pluginhandler.download_plugins(environment)
  end

  it "returns downloaded plugin, fact, and locale filenames" do
    Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(3).returns(%w[/a]).then.returns(%w[/b]).then.returns(%w[/c])

    expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b /c])
  end
end
