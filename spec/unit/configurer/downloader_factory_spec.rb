#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'

describe Puppet::Configurer::DownloaderFactory do
  let(:factory)     { Puppet::Configurer::DownloaderFactory.new }
  let(:environment) { Puppet::Node::Environment.create(:myenv, []) }

  let(:plugin_downloader) do
    factory.create_plugin_downloader(environment)
  end

  let(:facts_downloader) do
    factory.create_plugin_facts_downloader(environment)
  end

  def ignores_source_permissions(downloader)
    expect(downloader.file[:source_permissions]).to eq(:ignore)
  end

  def uses_source_permissions(downloader)
    expect(downloader.file[:source_permissions]).to eq(:use)
  end

  context "when creating a plugin downloader for modules" do
    it 'is named "plugin"' do
      expect(plugin_downloader.name).to eq('plugin')
    end

    it 'downloads files into Puppet[:plugindest]' do
      plugindest = File.expand_path("/tmp/pdest")
      Puppet[:plugindest] = plugindest

      expect(plugin_downloader.file[:path]).to eq(plugindest)
    end

    it 'downloads files from Puppet[:pluginsource]' do
      Puppet[:pluginsource] = 'puppet:///myotherplugins'

      expect(plugin_downloader.file[:source]).to eq([Puppet[:pluginsource]])
    end

    it 'ignores files from Puppet[:pluginsignore]' do
      Puppet[:pluginsignore] = 'pignore'

      expect(plugin_downloader.file[:ignore]).to eq(['pignore'])
    end

    it 'splits Puppet[:pluginsignore] on whitespace' do
      Puppet[:pluginsignore] = ".svn CVS .git"

      expect(plugin_downloader.file[:ignore]).to eq(%w[.svn CVS .git])
    end

    it "ignores source permissions" do
      ignores_source_permissions(plugin_downloader)
    end
  end

  context "when creating a plugin downloader for external facts" do
    it 'is named "pluginfacts"' do
      expect(facts_downloader.name).to eq('pluginfacts')
    end

    it 'downloads files into Puppet[:pluginfactdest]' do
      plugindest = File.expand_path("/tmp/pdest")
      Puppet[:pluginfactdest] = plugindest

      expect(facts_downloader.file[:path]).to eq(plugindest)
    end

    it 'downloads files from Puppet[:pluginfactsource]' do
      Puppet[:pluginfactsource] = 'puppet:///myotherfacts'

      expect(facts_downloader.file[:source]).to eq([Puppet[:pluginfactsource]])
    end

    it 'ignores files from Puppet[:pluginsignore]' do
      Puppet[:pluginsignore] = 'pignore'

      expect(facts_downloader.file[:ignore]).to eq(['pignore'])
    end

    context "on POSIX", :if => Puppet.features.posix? do
      it "uses source permissions" do
        uses_source_permissions(facts_downloader)
      end
    end

    context "on Windows", :if => Puppet.features.microsoft_windows? do
      it "ignores source permissions during external fact pluginsync" do
        ignores_source_permissions(facts_downloader)
      end
    end
  end
end
