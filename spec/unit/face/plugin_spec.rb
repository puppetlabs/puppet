#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:plugin, :current] do

  let(:pluginface) { described_class }
  let(:action) { pluginface.get_action(:download) }

  def render(result)
    action.when_rendering(:console).call(result)
  end

  context "download" do
    before :each do
      #Server_agent version needs to be at 5.3.4 in order to mount locales
      Puppet.push_context({:server_agent_version => "5.3.4"})
    end

    it "downloads plugins, external facts, and locales" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(3).returns([])

      pluginface.download
    end

    it "renders 'No plugins downloaded' if nothing was downloaded" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(3).returns([])

      result = pluginface.download
      expect(render(result)).to eq('No plugins downloaded.')
    end

    it "renders comma separate list of downloaded file names" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(3).returns(%w[/a]).then.returns(%w[/b]).then.returns(%w[/c])

      result = pluginface.download
      expect(render(result)).to eq('Downloaded these plugins: /a, /b, /c')
    end
  end

  context "download when server_agent_version is 5.3.3" do
    before :each do
      #Server_agent version needs to be at 5.3.4 in order to mount locales
      Puppet.push_context({:server_agent_version => "5.3.3"})
    end

    it "downloads plugins, and external facts, but not locales" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(2).returns([])

      pluginface.download
    end

    it "renders comma separate list of downloaded file names that does not include locales" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(2).returns(%w[/a]).then.returns(%w[/b])

      result = pluginface.download
      expect(render(result)).to eq('Downloaded these plugins: /a, /b')
    end
  end

  context "download when server_agent_version is blank" do
    before :each do
      #Server_agent version needs to be at 5.3.4 in order to mount locales
      #A blank version will default to 0.0
      Puppet.push_context({:server_agent_version => ""})
    end

    it "downloads plugins, and external facts, but not locales" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(2).returns([])

      pluginface.download
    end

    it "renders comma separate list of downloaded file names that does not include locales" do
      Puppet::Configurer::Downloader.any_instance.expects(:evaluate).times(2).returns(%w[/a]).then.returns(%w[/b])

      result = pluginface.download
      expect(render(result)).to eq('Downloaded these plugins: /a, /b')
    end
  end
end
