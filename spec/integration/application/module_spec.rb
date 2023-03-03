# coding: utf-8
require 'spec_helper'
require 'puppet/forge'
require 'puppet_spec/https'

describe 'puppet module', unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  include_context "https client"

  let(:app) { Puppet::Application[:module] }
  let(:wrong_hostname) { 'localhost' }
  let(:server) { PuppetSpec::HTTPSServer.new }
  let(:ssl_provider) { Puppet::SSL::SSLProvider.new }

  let(:release_response) { File.read(fixtures('unit/forge/bacula-releases.json')) }
  let(:release_tarball) { File.binread(fixtures('unit/forge/bacula.tar.gz')) }
  let(:target_dir) { tmpdir('bacula') }

  before :each do
    SemanticPuppet::Dependency.clear_sources
  end

  it 'installs a module' do
    # create a temp cacert bundle
    ssl_file = tmpfile('systemstore')
    File.write(ssl_file, server.ca_cert)

    response_proc = -> (req, res) {
      if req.path == '/v3/releases'
        res['Content-Type'] = 'application/json'
        res.body = release_response
      else
        res['Content-Type'] = 'application/octet-stream'
        res.body = release_tarball
      end
      res.status = 200
    }

    # override path to system cacert bundle, this must be done before
    # the SSLContext is created and the call to X509::Store.set_default_paths
    Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
      server.start_server(response_proc: response_proc) do |port|
        Puppet[:module_repository] = "https://127.0.0.1:#{port}"

        # On Windows, CP437 encoded output can't be matched against UTF-8 regexp,
        # so encode the regexp to the external encoding and match against that.
        app.command_line.args = ['install', 'puppetlabs-bacula', '--target-dir', target_dir]
        expect {
          app.run
        }.to exit_with(0)
         .and output(Regexp.new("└── puppetlabs-bacula".encode(Encoding.default_external))).to_stdout
      end
    end
  end

  it 'returns a valid exception when there is an SSL verification problem' do
    server.start_server do |port|
      Puppet[:module_repository] = "https://#{wrong_hostname}:#{port}"

      expect {
        app.command_line.args = ['install', 'puppetlabs-bacula', '--target-dir', target_dir]
        app.run
      }.to exit_with(1)
       .and output(%r{Notice: Downloading from https://#{wrong_hostname}:#{port}}).to_stdout
       .and output(%r{Unable to verify the SSL certificate}).to_stderr
    end
  end

  it 'prints the complete URL it tried to connect to' do
    response_proc = -> (req, res) { res.status = 404 }

    # create a temp cacert bundle
    ssl_file = tmpfile('systemstore')
    File.write(ssl_file, server.ca_cert)

    Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
      server.start_server(response_proc: response_proc) do |port|
        Puppet[:module_repository] = "https://127.0.0.1:#{port}/bogus_test/puppet"

        expect {
          app.command_line.args = ['install', 'puppetlabs-bacula']
          app.run
        }.to exit_with(1)
         .and output(%r{Notice: Downloading from https://127.0.0.1:#{port}}).to_stdout
         .and output(%r{https://127.0.0.1:#{port}/bogus_test/puppet/v3/releases}).to_stderr
      end
    end
  end

  context 'install' do
    it 'lists a module in a non-default directory environment' do
      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(my_fixture_dir, 'environments')

      expect {
        app.command_line.args = ['list']
        app.run
      }.to exit_with(0)
       .and output(Regexp.new("└── pmtacceptance-nginx".encode(Encoding.default_external), Regexp::MULTILINE)).to_stdout
    end
  end

  context 'changes' do
    it 'reports an error when the install path is invalid' do
      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(my_fixture_dir, 'environments')
      dir = tmpdir('module_changes')

      pattern = Regexp.new([
        %Q{.*Error: Could not find a valid module at "#{dir}/nginx".*},
        %Q{.*Error: Try 'puppet help module changes' for usage.*},
      ].join("\n"), Regexp::MULTILINE)

      expect {
        app.command_line.args = ['changes', File.join(dir, 'nginx')]
        app.run
      }.to exit_with(1)
       .and output(pattern).to_stderr
    end

    it 'reports when checksums are missing from metadata.json' do
      tmp = tmpdir('module_invalid_checksums')
      FileUtils.cp_r(File.join(my_fixture_dir, 'environments'), tmp)

      # overwrite checksums in metadata.json
      nginx_dir = File.join(tmp, 'environments', 'direnv', 'modules', 'nginx')
      File.write(File.join(nginx_dir, 'metadata.json'), <<~END)
        {
          "name": "pmtacceptance/nginx",
          "version": "0.0.1"
        }
      END

      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(tmp, 'environments')

      pattern = Regexp.new([
        %Q{.*Error: No file containing checksums found.*},
        %Q{.*Error: Try 'puppet help module changes' for usage.*},
      ].join("\n"), Regexp::MULTILINE)

      expect {
        app.command_line.args = ['changes', nginx_dir]
        app.run
      }.to exit_with(1)
        .and output(pattern).to_stderr
    end

    it 'reports module not found when metadata.json is missing' do
      tmp = tmpdir('module_missing_metadata')
      FileUtils.cp_r(File.join(my_fixture_dir, 'environments'), tmp)

      # overwrite checksums in metadata.json
      nginx_dir = File.join(tmp, 'environments', 'direnv', 'modules', 'nginx')
      File.unlink(File.join(nginx_dir, 'metadata.json'))

      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(tmp, 'environments')

      pattern = Regexp.new([
        %Q{.*Error: Could not find a valid module at.*},
        %Q{.*Error: Try 'puppet help module changes' for usage.*},
      ].join("\n"), Regexp::MULTILINE)

      expect {
        app.command_line.args = ['changes', nginx_dir]
        app.run
      }.to exit_with(1)
        .and output(pattern).to_stderr
    end

    it 'reports when a file is modified' do
      tmp = tmpdir('module_modified_metadata')
      FileUtils.cp_r(File.join(my_fixture_dir, 'environments'), tmp)

      # overwrite README so checksum doesn't match
      nginx_dir = File.join(tmp, 'environments', 'direnv', 'modules', 'nginx')
      File.write(File.join(nginx_dir, 'README'), '')

      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(tmp, 'environments')

      pattern = Regexp.new([
        %Q{.*Warning: 1 files modified.*},
      ].join("\n"), Regexp::MULTILINE)

      expect {
        app.command_line.args = ['changes', nginx_dir]
        app.run
      }.to exit_with(0)
        .and output(%r{README}).to_stdout
        .and output(pattern).to_stderr
    end

    it 'reports when a file is missing' do
      tmp = tmpdir('module_missing_file')
      FileUtils.cp_r(File.join(my_fixture_dir, 'environments'), tmp)

      # delete README so checksum doesn't match
      nginx_dir = File.join(tmp, 'environments', 'direnv', 'modules', 'nginx')
      File.unlink(File.join(nginx_dir, 'README'))

      Puppet.initialize_settings(['-E', 'direnv'])
      Puppet[:color] = false
      Puppet[:environmentpath] = File.join(tmp, 'environments')

      # odd that it says modified
      pattern = Regexp.new([
        %Q{.*Warning: 1 files modified.*},
      ].join("\n"), Regexp::MULTILINE)

      expect {
        app.command_line.args = ['changes', nginx_dir]
        app.run
      }.to exit_with(0)
        .and output(%r{README}).to_stdout
        .and output(pattern).to_stderr
    end
  end
end
