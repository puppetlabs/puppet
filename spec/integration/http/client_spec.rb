require 'spec_helper'
require 'puppet_spec/https'
require 'puppet_spec/files'

describe Puppet::HTTP::Client, unless: Puppet::Util::Platform.jruby? do
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
  let(:client) { Puppet::HTTP::Client.new }
  let(:ssl_provider) { Puppet::SSL::SSLProvider.new }
  let(:root_context) { ssl_provider.create_root_context(cacerts: [server.ca_cert], crls: [server.ca_crl]) }

  context "when verifying an HTTPS server" do
    it "connects over SSL" do
      server.start_server do |port|
        res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: root_context})
        expect(res).to be_success
      end
    end

    it "raises connection error if we can't connect" do
      Puppet[:http_connect_timeout] = '0s'

      # get available port, but don't bind to it
      tcps = TCPServer.new("127.0.0.1", 0)
      port = tcps.connect_address.ip_port

      expect {
        client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: root_context})
      }.to raise_error(Puppet::HTTP::ConnectionError, %r{^Request to https://127.0.0.1:#{port} timed out connect operation after .* seconds})
    end

    it "raises if the server's cert doesn't match the hostname we connected to" do
      server.start_server do |port|
        expect {
          client.get(URI("https://#{wrong_hostname}:#{port}"), options: {ssl_context: root_context})
        }.to raise_error { |err|
          expect(err).to be_instance_of(Puppet::SSL::CertMismatchError)
          expect(err.message).to match(/Server hostname '#{wrong_hostname}' did not match server certificate; expected one of (.+)/)

          md = err.message.match(/expected one of (.+)/)
          expect(md[1].split(', ')).to contain_exactly('127.0.0.1', 'DNS:127.0.0.1', 'DNS:127.0.0.2')
        }
      end
    end

    it "raises if the server's CA is unknown" do
      wrong_ca = cert_fixture('netlock-arany-utf8.pem')
      alt_context = ssl_provider.create_root_context(cacerts: [wrong_ca], revocation: false)

      server.start_server do |port|
        expect {
          client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: alt_context})
        }.to raise_error(Puppet::SSL::CertVerifyError,
                         %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
      end
    end

    it "prints TLS protocol and ciphersuite in debug" do
      Puppet[:log_level] = 'debug'
      server.start_server do |port|
        client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: root_context})
        # TLS version string can be TLSv1 or TLSv1.[1-3], but not TLSv1.0
        expect(@logs).to include(
          an_object_having_attributes(level: :debug, message: /Using TLSv1(\.[1-3])? with cipher .*/),
        )
      end
    end
  end

  context "with client certs" do
    let(:ctx_proc) {
      -> ctx {
        # configures the server to require the client to present a client cert
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      }
    }

    it "mutually authenticates the connection" do
      client_context = ssl_provider.create_context(
        cacerts: [server.ca_cert], crls: [server.ca_crl],
        client_cert: server.server_cert, private_key: server.server_key
      )

      server.start_server(ctx_proc: ctx_proc) do |port|
        res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: client_context})
        expect(res).to be_success
      end
    end
  end

  context "with a system trust store" do
    it "connects when the client trusts the server's CA" do
      system_context = ssl_provider.create_system_context(cacerts: [server.ca_cert])

      server.start_server do |port|
        res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
        expect(res).to be_success
      end
    end

    it "connects when the server's CA is in the system store" do
      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      File.write(ssl_file, server.ca_cert)

      # override path to system cacert bundle, this must be done before
      # the SSLContext is created and the call to X509::Store.set_default_paths
      Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
        system_context = ssl_provider.create_system_context(cacerts: [])
        server.start_server do |port|
          res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
          expect(res).to be_success
        end
      end
    end

    it "raises if the server's CA is not in the context or system store" do
      system_context = ssl_provider.create_system_context(cacerts: [cert_fixture('netlock-arany-utf8.pem')])

      server.start_server do |port|
        expect {
          client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
        }.to raise_error(Puppet::SSL::CertVerifyError,
                         %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
      end
    end
  end

  context 'persistent connections' do
    it "detects when the server has closed the connection and reconnects" do
      server.start_server do |port|
        uri = URI("https://127.0.0.1:#{port}")

        expect(client.get(uri, options: {ssl_context: root_context})).to be_success
        expect(client.get(uri, options: {ssl_context: root_context})).to be_success
      end
    end
  end
end
