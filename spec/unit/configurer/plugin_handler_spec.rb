require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/plugin_handler'

describe Puppet::Configurer::PluginHandler do
  let(:pluginhandler) { Puppet::Configurer::PluginHandler.new() }
  let(:environment)   { Puppet::Node::Environment.create(:myenv, []) }

  before :each do
    # PluginHandler#load_plugin has an extra-strong rescue clause
    # this mock is to make sure that we don't silently ignore errors
    expect(Puppet).not_to receive(:err)
  end

  context "server agent version is 5.3.4" do
    around do |example|
      Puppet.override(server_agent_version: "5.3.4") do
        example.run
      end
    end

    it "downloads plugins, facts, and locales" do
      times_called = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) { times_called += 1 }.and_return([])

      pluginhandler.download_plugins(environment)
      expect(times_called).to eq(3)
    end

    it "returns downloaded plugin, fact, and locale filenames" do
      times_called = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        times_called += 1

        if times_called == 1
          %w[/a]
        elsif times_called == 2
          %w[/b]
        else
          %w[/c]
        end
      end

      expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b /c])
      expect(times_called).to eq(3)
    end
  end

  context "server agent version is 5.3.3" do
    around do |example|
      Puppet.override(server_agent_version: "5.3.3") do
        example.run
      end
    end

    it "returns downloaded plugin, fact, but not locale filenames" do
      times_called = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        times_called += 1

        if times_called == 1
          %w[/a]
        else
          %w[/b]
        end
      end

      expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b])
      expect(times_called).to eq(2)
    end
  end

  context "blank server agent version" do
    around do |example|
      Puppet.override(server_agent_version: "") do
        example.run
      end
    end

    it "returns downloaded plugin, fact, but not locale filenames" do
      times_called = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        times_called += 1

        if times_called == 1
          %w[/a]
        else
          %w[/b]
        end
      end

      expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b])
      expect(times_called).to eq(2)
    end
  end
end
