require 'spec_helper'
require 'puppet_spec/https'
require 'puppet_spec/files'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  before :all do
    WebMock.disable!
  end

  after :all do
    WebMock.enable!
  end

  before :each do
    # make sure we don't take too long
    Puppet[:http_connect_timeout] = '5s'
  end

  let(:hostname) { '127.0.0.1' }
  let(:wrong_hostname) { 'localhost' }
  let(:server) { PuppetSpec::HTTPSServer.new }

  context "when calling deprecated HttpPool methods" do
    before(:each) do
      ssldir = tmpdir('http_pool')
      Puppet[:ssldir] = ssldir
      Puppet.settings.use(:main, :ssl)

      File.write(Puppet[:localcacert], server.ca_cert.to_pem)
      File.write(Puppet[:hostcrl], server.ca_crl.to_pem)
      File.write(Puppet[:hostcert], server.server_cert.to_pem)
      File.write(Puppet[:hostprivkey], server.server_key.to_pem)
    end

    def connection(host, port)
      Puppet::Network::HttpPool.http_instance(host, port, use_ssl: true)
    end

    shared_examples_for 'HTTPS client' do
      it "connects over SSL" do
        server.start_server do |port|
          http = connection(hostname, port)
          res = http.get('/')
          expect(res.code).to eq('200')
        end
      end

      it "raises if the server's cert doesn't match the hostname we connected to" do
        server.start_server do |port|
          http = connection(wrong_hostname, port)
          expect {
            http.get('/')
          }.to raise_error { |err|
            expect(err).to be_instance_of(Puppet::SSL::CertMismatchError)
            expect(err.message).to match(/\AServer hostname '#{wrong_hostname}' did not match server certificate; expected one of (.+)/)

            md = err.message.match(/expected one of (.+)/)
            expect(md[1].split(', ')).to contain_exactly('127.0.0.1', 'DNS:127.0.0.1', 'DNS:127.0.0.2')
          }
        end
      end

      it "raises if the server's CA is unknown" do
        # File must exist and by not empty so DefaultValidator doesn't
        # downgrade to VERIFY_NONE, so use a different CA that didn't
        # issue the server's cert
        capath = tmpfile('empty')
        File.write(capath, cert_fixture('netlock-arany-utf8.pem'))
        Puppet[:localcacert] = capath
        Puppet[:certificate_revocation] = false

        server.start_server do |port|
          http = connection(hostname, port)
          expect {
            http.get('/')
          }.to raise_error(Puppet::Error,
                           %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
        end
      end

      it "doesn't generate a Puppet::SSL::Host deprecation warning" do
        server.start_server do |port|
          http = connection(hostname, port)
          res = http.get('/')
          expect(res.code).to eq('200')
        end

        expect(@logs).to eq([])
      end

      it "detects when the server has closed the connection and reconnects" do
        server.start_server do |port|
          http = connection(hostname, port)

          expect(http.request_get('/')).to be_a(Net::HTTPSuccess)
          expect(http.request_get('/')).to be_a(Net::HTTPSuccess)
        end
      end
    end

    context "when using persistent HTTPS connections" do
      around :each do |example|
        begin
          example.run
        ensure
          Puppet.runtime[:http].close
        end
      end

      include_examples 'HTTPS client'
    end

    shared_examples_for "an HttpPool connection" do |klass, legacy_api|
      before :each do
        Puppet::Network::HttpPool.http_client_class = klass
      end

      it "connects using the scheme, host and port from the http instance preserving the URL path and query" do
        request_line = nil

        response_proc = -> (req, res) {
          request_line = req.request_line
        }

        server.start_server(response_proc: response_proc) do |port|
          http = Puppet::Network::HttpPool.http_instance(hostname, port, true)
          path  = "http://bogus.example.com:443/foo?q=a"
          http.get(path)

          if legacy_api
            # The old API uses 'absolute-form' and passes the bogus hostname
            # which isn't the host we connected to.
            expect(request_line).to eq("GET http://bogus.example.com:443/foo?q=a HTTP/1.1\r\n")
          else
            expect(request_line).to eq("GET /foo?q=a HTTP/1.1\r\n")
          end
        end
      end

      it "requires the caller to URL encode the path and query when using absolute form" do
        request_line = nil

        response_proc = -> (req, res) {
          request_line = req.request_line
        }

        server.start_server(response_proc: response_proc) do |port|
          http = Puppet::Network::HttpPool.http_instance(hostname, port, true)
          params = { 'key' => 'a value' }
          encoded_url = "https://#{hostname}:#{port}/foo%20bar?q=#{Puppet::Util.uri_query_encode(params.to_json)}"
          http.get(encoded_url)

          if legacy_api
            expect(request_line).to eq("GET #{encoded_url} HTTP/1.1\r\n")
          else
            expect(request_line).to eq("GET /foo%20bar?q=%7B%22key%22%3A%22a%20value%22%7D HTTP/1.1\r\n")
          end
        end
      end

      it "requires the caller to URL encode the path and query when using a path" do
        request_line = nil

        response_proc = -> (req, res) {
          request_line = req.request_line
        }

        server.start_server(response_proc: response_proc) do |port|
          http = Puppet::Network::HttpPool.http_instance(hostname, port, true)
          params = { 'key' => 'a value' }
          http.get("/foo%20bar?q=#{Puppet::Util.uri_query_encode(params.to_json)}")

          expect(request_line).to eq("GET /foo%20bar?q=%7B%22key%22%3A%22a%20value%22%7D HTTP/1.1\r\n")
        end
      end
    end

    describe Puppet::Network::HTTP::Connection do
      it_behaves_like "an HttpPool connection", described_class, false
    end
  end

  context "when calling HttpPool.connection method" do
    let(:ssl) { Puppet::SSL::SSLProvider.new }
    let(:ssl_context) { ssl.create_root_context(cacerts: [server.ca_cert], crls: [server.ca_crl]) }

    def connection(host, port, ssl_context:)
      Puppet::Network::HttpPool.connection(host, port, ssl_context: ssl_context)
    end

    # Configure the server's SSLContext to require a client certificate. The `client_ca`
    # setting allows the server to advertise which client CAs it will accept.
    def require_client_certs(ctx)
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      ctx.client_ca = [cert_fixture('ca.pem')]
    end

    it "connects over SSL" do
      server.start_server do |port|
        http = connection(hostname, port, ssl_context: ssl_context)
        res = http.get('/')
        expect(res.code).to eq('200')
      end
    end

    it "raises if the server's cert doesn't match the hostname we connected to" do
      server.start_server do |port|
        http = connection(wrong_hostname, port, ssl_context: ssl_context)
        expect {
          http.get('/')
        }.to raise_error { |err|
          expect(err).to be_instance_of(Puppet::SSL::CertMismatchError)
          expect(err.message).to match(/\AServer hostname '#{wrong_hostname}' did not match server certificate; expected one of (.+)/)

          md = err.message.match(/expected one of (.+)/)
          expect(md[1].split(', ')).to contain_exactly('127.0.0.1', 'DNS:127.0.0.1', 'DNS:127.0.0.2')
        }
      end
    end

    it "raises if the server's CA is unknown" do
      server.start_server do |port|
        ssl_context = ssl.create_root_context(cacerts: [cert_fixture('netlock-arany-utf8.pem')],
                                              crls: [server.ca_crl])
        http = Puppet::Network::HttpPool.connection(hostname, port, ssl_context: ssl_context)
        expect {
          http.get('/')
        }.to raise_error(Puppet::Error,
                         %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
      end
    end

    it "warns when client has an incomplete client cert chain" do
      expect(Puppet).to receive(:warning).with("The issuer 'CN=Test CA Agent Subauthority' of certificate 'CN=pluto' cannot be found locally")

      pluto = cert_fixture('pluto.pem')

      ssl_context = ssl.create_context(
        cacerts: [server.ca_cert], crls: [server.ca_crl],
        client_cert: pluto, private_key: key_fixture('pluto-key.pem')
      )

      # verify client has incomplete chain
      expect(ssl_context.client_chain.map(&:to_der)).to eq([pluto.to_der])

      # force server to require (not request) client certs
      ctx_proc = -> (ctx) {
        require_client_certs(ctx)

        # server needs to trust the client's intermediate CA to complete the client's chain
        ctx.cert_store.add_cert(cert_fixture('intermediate-agent.pem'))
      }

      server.start_server(ctx_proc: ctx_proc) do |port|
        http = Puppet::Network::HttpPool.connection(hostname, port, ssl_context: ssl_context)
        res = http.get('/')
        expect(res.code).to eq('200')
      end
    end

    it "sends a complete client cert chain" do
      pluto = cert_fixture('pluto.pem')
      client_ca = cert_fixture('intermediate-agent.pem')

      ssl_context = ssl.create_context(
        cacerts: [server.ca_cert, client_ca],
        crls: [server.ca_crl, crl_fixture('intermediate-agent-crl.pem')],
        client_cert: pluto,
        private_key: key_fixture('pluto-key.pem')
      )

      # verify client has complete chain from leaf to root
      expect(ssl_context.client_chain.map(&:to_der)).to eq([pluto, client_ca, server.ca_cert].map(&:to_der))

      server.start_server(ctx_proc: method(:require_client_certs)) do |port|
        http = Puppet::Network::HttpPool.connection(hostname, port, ssl_context: ssl_context)
        res = http.get('/')
        expect(res.code).to eq('200')
      end
    end
  end
end
