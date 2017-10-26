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
end
