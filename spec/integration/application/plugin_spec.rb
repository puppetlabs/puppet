require 'spec_helper'
require 'puppet/face'
require 'puppet_spec/puppetserver'

describe "puppet plugin" do
  include_context "https client"

  let(:server) { PuppetSpec::Puppetserver.new }
  let(:plugin) { Puppet::Application[:plugin] }
  let(:response_body) { "[{\"path\":\"/etc/puppetlabs/code/environments/production/modules\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-03-06 20:14:25 UTC\"},\"type\":\"directory\",\"destination\":null}]" }

  it "downloads from plugins, pluginsfacts and locales mounts" do
    current_version_handler = -> (req, res) {
      res['X-Puppet-Version'] = Puppet.version
      res['Content-Type'] = 'application/json'
      res.body = response_body
    }

    server.start_server(mounts: {file_metadatas: current_version_handler}) do |port|
      Puppet[:masterport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching(
         "Downloaded these plugins: #{Regexp.escape(Puppet[:pluginfactdest])}, #{Regexp.escape(Puppet[:plugindest])}, #{Regexp.escape(Puppet[:localedest])}"
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
      Puppet[:masterport] = port
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
      Puppet[:masterport] = port
      expect {
        plugin.command_line.args << 'download'
        plugin.run
      }.to exit_with(0)
       .and output(matching("Downloaded these plugins")).to_stdout

      expect(requested_environment).to eq('doesnotexistontheagent')
    end
  end

end
