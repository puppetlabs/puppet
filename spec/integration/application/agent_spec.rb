require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/puppetserver'
require 'puppet_spec/compiler'
require 'puppet_spec/https'

describe "puppet agent", unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  include PuppetSpec::Compiler
  include_context "https client"

  let(:server) { PuppetSpec::Puppetserver.new }
  let(:agent) { Puppet::Application[:agent] }
  let(:node) { Puppet::Node.new(Puppet[:certname], environment: 'production')}
  let(:formatter) { Puppet::Network::FormatHandler.format(:rich_data_json) }

  context 'server_list' do
    before :each do
      Puppet[:log_level] = 'debug'
    end

    it "uses the first server in the list" do
      Puppet[:server_list] = '127.0.0.1'

      server.start_server do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(0)
        }.to output(%r{HTTP GET https://127.0.0.1:#{port}/status/v1/simple/master returned 200 OK}).to_stdout
      end
    end

    it "falls back, recording the first viable server in the report" do
      Puppet[:server_list] = "puppet.example.com,#{Puppet[:server]}"

      server.start_server do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(0)
        }.to output(%r{Unable to connect to server from server_list setting: Request to https://puppet.example.com:#{port}/status/v1/simple/master failed}).to_stdout

        report = Puppet::Transaction::Report.convert_from(:yaml, File.read(Puppet[:lastrunreport]))
        expect(report.master_used).to eq("127.0.0.1:#{port}")
      end
    end

    it "doesn't write a report if no servers could be contacted" do
      Puppet[:server_list] = "puppet.example.com"

      expect {
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(1)
        }.to output(%r{Unable to connect to server from server_list setting: Could not select a functional puppet master from server_list: 'puppet.example.com'}).to_stdout
      }.to output(/Error: Could not run Puppet configuration client: Could not select a functional puppet master from server_list: 'puppet.example.com'/).to_stderr

      # I'd expect puppet to update the last run report even if the server_list was
      # exhausted, but it doesn't work that way currently, see PUP-6708
      expect(File).to_not be_exist(Puppet[:lastrunreport])
    end

    it "omits master_used when not using server_list" do
      server.start_server do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(0)
        }.to output(%r{Resolved service 'puppet' to https://127.0.0.1:#{port}/puppet/v3}).to_stdout
      end

      report = Puppet::Transaction::Report.convert_from(:yaml, File.read(Puppet[:lastrunreport]))
      expect(report.master_used).to be_nil
    end

    it "server_list takes precedence over server" do
      Puppet[:server] = 'notvalid.example.com'

      server.start_server do |port|
        Puppet[:server_list] = "127.0.0.1:#{port}"

        expect {
          agent.command_line.args << '--test'
          agent.run
        }.to exit_with(0)
         .and output(%r{Debug: Resolved service 'puppet' to https://127.0.0.1:#{port}/puppet/v3}).to_stdout

        report = Puppet::Transaction::Report.convert_from(:yaml, File.read(Puppet[:lastrunreport]))
        expect(report.master_used).to eq("127.0.0.1:#{port}")
      end
    end
  end

  context 'rich data' do
    it "applies deferred values" do
      catalog_handler = -> (req, res) {
        catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'deferred':
            message => Deferred('join', [[1,2,3], ':'])
          }
        MANIFEST

        res.body = formatter.render(catalog)
        res['Content-Type'] = formatter.mime
      }

      server.start_server(mounts: {catalog: catalog_handler}) do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(2)
        }.to output(%r{Notice: /Stage\[main\]/Main/Notify\[deferred\]/message: defined 'message' as '1:2:3'}).to_stdout
      end
    end

    it "redacts sensitive values" do
      catalog_handler = -> (req, res) {
        catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'sensitive':
            message => Sensitive('supersecret')
          }
        MANIFEST

        res.body = formatter.render(catalog)
        res['Content-Type'] = formatter.mime
      }

      server.start_server(mounts: {catalog: catalog_handler}) do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(2)
        }.to output(a_string_matching(
          /Notice: Sensitive \[value redacted\]/
        ).and matching(
          /Notify\[sensitive\]\/message: changed \[redacted\] to \[redacted\]/
        )).to_stdout
      end
    end

    it "applies binary data in a cached catalog" do
      catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'some title':
            message => Binary.new('aGk=')
          }
        MANIFEST

      catalog_dir = File.join(Puppet[:client_datadir], 'catalog')
      Puppet::FileSystem.mkpath(catalog_dir)
      cached_catalog = "#{File.join(catalog_dir, Puppet[:certname])}.json"
      File.write(cached_catalog, catalog.render(:rich_data_json))

      expect {
        Puppet[:report] = false
        Puppet[:use_cached_catalog] = true
        Puppet[:usecacheonfailure] = false
        agent.command_line.args << '-t'
        agent.run
      }.to exit_with(2)
       .and output(%r{defined 'message' as 'hi'}).to_stdout
    end
  end

  context 'static catalogs' do
    let(:path) { tmpfile('file') }
    let(:metadata) { Puppet::FileServing::Metadata.new(path) }
    let(:source) { "puppet:///modules/foo/foo.txt" }

    before :each do
      Puppet::FileSystem.touch(path)

      metadata.collect
      metadata.source = source
      metadata.content_uri = "puppet:///modules/foo/files/foo.txt"
    end

    it 'uses inline file metadata to determine the file is insync' do
      catalog_handler = -> (req, res) {
        catalog = compile_to_catalog(<<-MANIFEST, node)
          file { "#{path}":
            ensure => file,
            source => "#{source}"
          }
        MANIFEST
        catalog.metadata = { path => metadata }

        res.body = formatter.render(catalog)
        res['Content-Type'] = formatter.mime
      }

      server.start_server(mounts: {catalog: catalog_handler}) do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(0)
        }.to_not output(/content changed/).to_stdout
      end
    end

    it 'retrieves file content using the content_uri from the inlined file metadata' do
      # create file with binary content
      binary_content = "\xC0\xFF".force_encoding('binary')
      File.binwrite(path, binary_content)

      # recollect metadata
      metadata.collect

      # overwrite local file so it is no longer in sync
      File.binwrite(path, "")

      catalog_handler = -> (req, res) {
        catalog = compile_to_catalog(<<-MANIFEST, node)
          file { "#{path}":
            ensure => file,
            source => "#{source}",
          }
        MANIFEST
        catalog.metadata = { path => metadata }

        res.body = formatter.render(catalog)
        res['Content-Type'] = formatter.mime
      }

      static_file_content_handler = -> (req, res) {
        res.body = binary_content
        res['Content-Type'] = 'application/octet-stream'
      }

      mounts = {
        catalog: catalog_handler,
        static_file_content: static_file_content_handler
      }

      server.start_server(mounts: mounts) do |port|
        Puppet[:masterport] = port
        expect {
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(2)
        }.to output(/content changed '{md5}d41d8cd98f00b204e9800998ecf8427e' to '{md5}4cf49285ae567157ebfba72bd04ccf32'/).to_stdout

        # verify puppet restored binary content
        expect(File.binread(path)).to eq(binary_content)
      end
    end
  end

  context 'https file sources' do
    let(:path) { tmpfile('https_file_source') }
    let(:response_body) { "from https server" }
    let(:digest) { Digest::SHA1.hexdigest(response_body) }

    it 'rejects HTTPS servers whose root cert is not in the system CA store' do
      unknown_ca_cert = cert_fixture('unknown-ca.pem')
      https = PuppetSpec::HTTPSServer.new(
        ca_cert: unknown_ca_cert,
        server_cert: cert_fixture('unknown-127.0.0.1.pem'),
        server_key: key_fixture('unknown-127.0.0.1-key.pem')
      )

      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      # add CA cert that is neither the puppet CA nor unknown CA
      File.write(ssl_file, cert_fixture('netlock-arany-utf8.pem').to_pem)

      https.start_server do |https_port|
        catalog_handler = -> (req, res) {
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { "#{path}":
              ensure => file,
              backup => false,
              checksum => sha1,
              checksum_value => '#{digest}',
              source => "https://127.0.0.1:#{https_port}/path/to/file"
            }
          MANIFEST

          res.body = formatter.render(catalog)
          res['Content-Type'] = formatter.mime
        }

        server.start_server(mounts: {catalog: catalog_handler}) do |puppetserver_port|
          Puppet[:masterport] = puppetserver_port

          # override path to system cacert bundle, this must be done before
          # the SSLContext is created and the call to X509::Store.set_default_paths
          Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
            expect {
              agent.command_line.args << '--test'
              agent.run
            }.to exit_with(4)
             .and output(/Notice: Applied catalog/).to_stdout
             .and output(%r{Error: Could not retrieve file metadata for https://127.0.0.1:#{https_port}/path/to/file: certificate verify failed}).to_stderr
          end

          expect(File).to_not be_exist(path)
        end
      end
    end

    it 'accepts HTTPS servers whose cert is in the system CA store' do
      unknown_ca_cert = cert_fixture('unknown-ca.pem')
      https = PuppetSpec::HTTPSServer.new(
        ca_cert: unknown_ca_cert,
        server_cert: cert_fixture('unknown-127.0.0.1.pem'),
        server_key: key_fixture('unknown-127.0.0.1-key.pem')
      )

      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      File.write(ssl_file, unknown_ca_cert.to_pem)

      response_proc = -> (req, res) {
        res.status = 200
        res.body = response_body
      }

      https.start_server(response_proc: response_proc) do |https_port|
        catalog_handler = -> (req, res) {
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { "#{path}":
              ensure => file,
              backup => false,
              checksum => sha1,
              checksum_value => '#{digest}',
              source => "https://127.0.0.1:#{https_port}/path/to/file"
            }
          MANIFEST

          res.body = formatter.render(catalog)
          res['Content-Type'] = formatter.mime
        }

        server.start_server(mounts: {catalog: catalog_handler}) do |puppetserver_port|
          Puppet[:masterport] = puppetserver_port

          # override path to system cacert bundle, this must be done before
          # the SSLContext is created and the call to X509::Store.set_default_paths
          Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
            expect {
                agent.command_line.args << '--test'
                agent.run
            }.to exit_with(2)
             .and output(%r{https_file_source.*/ensure: created}).to_stdout
          end

          expect(File.binread(path)).to eq("from https server")
        end
      end
    end

    it 'accepts HTTPS servers whose cert is in the external CA store' do
      unknown_ca_cert = cert_fixture('unknown-ca.pem')
      https = PuppetSpec::HTTPSServer.new(
        ca_cert: unknown_ca_cert,
        server_cert: cert_fixture('unknown-127.0.0.1.pem'),
        server_key: key_fixture('unknown-127.0.0.1-key.pem')
      )

      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      File.write(ssl_file, unknown_ca_cert.to_pem)

      response_proc = -> (req, res) {
        res.status = 200
        res.body = response_body
      }

      https.start_server(response_proc: response_proc) do |https_port|
        catalog_handler = -> (req, res) {
          catalog = compile_to_catalog(<<-MANIFEST, node)
            file { "#{path}":
              ensure => file,
              backup => false,
              checksum => sha1,
              checksum_value => '#{digest}',
              source => "https://127.0.0.1:#{https_port}/path/to/file"
            }
          MANIFEST

          res.body = formatter.render(catalog)
          res['Content-Type'] = formatter.mime
        }

        server.start_server(mounts: {catalog: catalog_handler}) do |puppetserver_port|
          Puppet[:masterport] = puppetserver_port

          # set path to external cacert bundle, this must be done before
          # the SSLContext is created
          Puppet[:ssl_trust_store] = ssl_file
          expect {
            agent.command_line.args << '--test'
            agent.run
          }.to exit_with(2)
           .and output(%r{https_file_source.*/ensure: created}).to_stdout
        end

        expect(File.binread(path)).to eq("from https server")
      end
    end
  end

  context 'multiple agents running' do
    it "exits if an agent is already running" do
      path = Puppet[:agent_catalog_run_lockfile]

      th = Thread.new {
        %x{ruby -e "$0 = 'puppet'; File.write('#{path}', Process.pid); sleep(2)"}
      }

      until File.exists?(path) && File.size(path) > 0 do
        sleep 0.1
      end

      expect {
        agent.command_line.args << '--test'
        agent.run
      }.to exit_with(1).and output(/Run of Puppet configuration client already in progress; skipping/).to_stdout

      th.kill # kill thread so we don't wait too much
    end

    it "waits for other agent run to finish before starting" do
      server.start_server do |port|
        path = Puppet[:agent_catalog_run_lockfile]
        Puppet[:masterport] = port
        Puppet[:waitforlock] = 1

        th = Thread.new {
          %x{ruby -e "$0 = 'puppet'; File.write('#{path}', Process.pid); sleep(2)"}
        }

        until File.exists?(path) && File.size(path) > 0 do
          sleep 0.1
        end

        expect {
          agent.command_line.args << '--test'
          agent.run
        }.to exit_with(0).and output(/Info: Will try again in #{Puppet[:waitforlock]} seconds./).to_stdout

        th.kill # kill thread so we don't wait too much
      end
    end

    it "exits if maxwaitforlock is exceeded" do
      path = Puppet[:agent_catalog_run_lockfile]
      Puppet[:waitforlock] = 1
      Puppet[:maxwaitforlock] = 0

      th = Thread.new {
        %x{ruby -e "$0 = 'puppet'; File.write('#{path}', Process.pid); sleep(2)"}
      }

      until File.exists?(path) && File.size(path) > 0 do
        sleep 0.1
      end

      expect {
        agent.command_line.args << '--test'
        agent.run
      }.to exit_with(1).and output(/Exiting now because the maxwaitforlock timeout has been exceeded./).to_stdout

      th.kill # kill thread so we don't wait too much
    end
  end
end
