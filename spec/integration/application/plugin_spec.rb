require 'spec_helper'
require 'puppet/face'
require 'puppet_spec/puppetserver'

describe "puppet plugin" do
  include_context "https client"

  let(:server) { PuppetSpec::Puppetserver.new }
  let(:plugin) { Puppet::Application[:plugin] }
  let(:response_body) { "[{\"path\":\"/etc/puppetlabs/code/environments/production/modules\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-03-06 20:14:25 UTC\"},\"type\":\"directory\",\"destination\":null}]" }

  it "downloads from plugins, pluginsfacts and locales mounts when i18n is enabled" do
    Puppet[:disable_i18n] = false
    current_version_handler = -> (req, res) {
      res['X-Puppet-Version'] = Puppet.version
      res['Content-Type'] = 'application/json'
      res.body = response_body
    }

    server.start_server(mounts: {file_metadatas: current_version_handler}) do |port|
      Puppet[:serverport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching(
         "Downloaded these plugins: #{Regexp.escape(Puppet[:pluginfactdest])}, #{Regexp.escape(Puppet[:plugindest])}, #{Regexp.escape(Puppet[:localedest])}"
       )).to_stdout
    end
  end

  it "downloads from plugins, pluginsfacts but no locales mounts when i18n is disabled" do
    Puppet[:disable_i18n] = true

    current_version_handler = -> (req, res) {
      res['X-Puppet-Version'] = Puppet.version
      res['Content-Type'] = 'application/json'
      res.body = response_body
    }

    server.start_server(mounts: {file_metadatas: current_version_handler}) do |port|
      Puppet[:serverport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching(
         "Downloaded these plugins: #{Regexp.escape(Puppet[:pluginfactdest])}, #{Regexp.escape(Puppet[:plugindest])}"
       )).to_stdout
    end
  end

  it "downloads from plugins and pluginsfacts from older puppetservers" do
    no_locales_handler = -> (req, res) {
      res['X-Puppet-Version'] = '5.3.3' # locales mount was added in 5.3.4
      res['Content-Type'] = 'application/json'
      res.body = response_body
    }

    server.start_server(mounts: {file_metadatas: no_locales_handler}) do |port|
      Puppet[:serverport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching(
         "Downloaded these plugins: #{Regexp.escape(Puppet[:pluginfactdest])}, #{Regexp.escape(Puppet[:plugindest])}"
       )).to_stdout
    end
  end

  it "downloads from an environment that doesn't exist locally" do
    requested_environment = nil

    current_version_handler = -> (req, res) {
      res['X-Puppet-Version'] = Puppet.version
      res['Content-Type'] = 'application/json'
      res.body = response_body
      requested_environment = req.query['environment']
    }

    server.start_server(mounts: {file_metadatas: current_version_handler}) do |port|
      Puppet[:environment] = 'doesnotexistontheagent'
      Puppet[:serverport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching("Downloaded these plugins")).to_stdout

      expect(requested_environment).to eq('doesnotexistontheagent')
    end
  end

  context "pluginsync for external facts uses source permissions to preserve fact executable-ness" do
    before :all do
      WebMock.enable!
    end

    after :all do
      WebMock.disable!
    end

    before :each do
      metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":420,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
      stub_request(:get, %r{/puppet/v3/file_metadatas/(plugins|locales)}).to_return(status: 200, body: metadata, headers: {'Content-Type' => 'application/json'})

      # response retains owner/group/mode due to source_permissions => use
      facts_metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":500,\"group\":500,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
      stub_request(:get, %r{/puppet/v3/file_metadatas/pluginfacts}).to_return(status: 200, body: facts_metadata, headers: {'Content-Type' => 'application/json'})
    end

    it "processes a download request resulting in no changes" do
      # Create these so there are no changes
      Puppet::FileSystem.mkpath(Puppet[:plugindest])
      Puppet::FileSystem.mkpath(Puppet[:localedest])

      # /opt/puppetlabs/puppet/cache/facts.d will be created based on our umask.
      # If the mode on disk is not 0755, then the mode from the metadata response
      # (493 => 0755) will be applied, resulting in "plugins were downloaded"
      # message. Enforce a umask so the results are consistent.
      Puppet::FileSystem.mkpath(Puppet[:pluginfactdest])
      Puppet::FileSystem.chmod(0755, Puppet[:pluginfactdest])

      app = Puppet::Application[:plugin]
      app.command_line.args << 'download'
      expect {
        app.run
      }.to exit_with(0)
       .and output(/No plugins downloaded/).to_stdout
    end

    it "updates the facts.d mode", unless: Puppet::Util::Platform.windows? do
      Puppet::FileSystem.mkpath(Puppet[:pluginfactdest])
      Puppet::FileSystem.chmod(0775, Puppet[:pluginfactdest])

      app = Puppet::Application[:plugin]
      app.command_line.args << 'download'
      expect {
        app.run
      }.to exit_with(0)
       .and output(/Downloaded these plugins: .*facts\.d/).to_stdout
    end
  end
end
