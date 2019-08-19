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
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) { receive_count += 1 }.and_return([])

      pluginface.download
      expect(receive_count).to eq(3)
    end

    it "renders 'No plugins downloaded' if nothing was downloaded" do
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) { receive_count += 1 }.and_return([])

      result = pluginface.download
      expect(receive_count).to eq(3)
      expect(render(result)).to eq('No plugins downloaded.')
    end

    it "renders comma separate list of downloaded file names" do
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        receive_count += 1
        case receive_count
        when 1
          %w[/a]
        when 2
          %w[/b]
        when 3
          %w[/c]
        end
      end

      result = pluginface.download
      expect(receive_count).to eq(3)
      expect(render(result)).to eq('Downloaded these plugins: /a, /b, /c')
    end

    it "uses persistent HTTP pool" do
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        expect(Puppet.lookup(:http_pool)).to be_instance_of(Puppet::Network::HTTP::Pool)
      end.and_return([])

      pluginface.download
    end
  end

  context "download when server_agent_version is 5.3.3" do
    before :each do
      #Server_agent version needs to be at 5.3.4 in order to mount locales
      Puppet.push_context({:server_agent_version => "5.3.3"})
    end

    it "downloads plugins, and external facts, but not locales" do
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) { receive_count += 1}.and_return([])

      pluginface.download
    end

    it "renders comma separate list of downloaded file names that does not include locales" do
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        receive_count += 1
        receive_count == 1 ? %w[/a] : %w[/b]
      end

      result = pluginface.download
      expect(receive_count).to eq(2)
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
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) { receive_count += 1 }.and_return([])

      pluginface.download
      expect(receive_count).to eq(2)
    end

    it "renders comma separate list of downloaded file names that does not include locales" do
      receive_count = 0
      allow_any_instance_of(Puppet::Configurer::Downloader).to receive(:evaluate) do
        receive_count += 1
        receive_count == 1 ? %w[/a] : %w[/b]
      end

      result = pluginface.download
      expect(receive_count).to eq(2)
      expect(render(result)).to eq('Downloaded these plugins: /a, /b')
    end
  end
end
