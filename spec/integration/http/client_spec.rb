require 'spec_helper'
require 'puppet_spec/https'
require 'puppet_spec/files'

describe Puppet::HTTP::Client, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  include_context "https client"

  let(:wrong_hostname) { 'localhost' }
  let(:client) { Puppet::HTTP::Client.new }
  let(:ssl_provider) { Puppet::SSL::SSLProvider.new }
  let(:root_context) { ssl_provider.create_root_context(cacerts: [https_server.ca_cert], crls: [https_server.ca_crl]) }

  context "when verifying an HTTPS server" do
    it "connects over SSL" do
      https_server.start_server do |port|
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
      https_server.start_server do |port|
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

      https_server.start_server do |port|
        expect {
          client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: alt_context})
        }.to raise_error(Puppet::SSL::CertVerifyError,
                         %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
      end
    end

    it "prints TLS protocol and ciphersuite in debug" do
      Puppet[:log_level] = 'debug'
      https_server.start_server do |port|
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
        cacerts: [https_server.ca_cert], crls: [https_server.ca_crl],
        client_cert: https_server.server_cert, private_key: https_server.server_key
      )

      https_server.start_server(ctx_proc: ctx_proc) do |port|
        res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: client_context})
        expect(res).to be_success
      end
    end
  end

  context "with a system trust store" do
    it "connects when the client trusts the server's CA" do
      system_context = ssl_provider.create_system_context(cacerts: [https_server.ca_cert])

      https_server.start_server do |port|
        res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
        expect(res).to be_success
      end
    end

    it "connects when the server's CA is in the system store" do
      # create a temp cacert bundle
      ssl_file = tmpfile('systemstore')
      File.write(ssl_file, https_server.ca_cert)

      # override path to system cacert bundle, this must be done before
      # the SSLContext is created and the call to X509::Store.set_default_paths
      Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
        system_context = ssl_provider.create_system_context(cacerts: [])
        https_server.start_server do |port|
          res = client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
          expect(res).to be_success
        end
      end
    end

    it "raises if the server's CA is not in the context or system store" do
      system_context = ssl_provider.create_system_context(cacerts: [cert_fixture('netlock-arany-utf8.pem')])

      https_server.start_server do |port|
        expect {
          client.get(URI("https://127.0.0.1:#{port}"), options: {ssl_context: system_context})
        }.to raise_error(Puppet::SSL::CertVerifyError,
                         %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
      end
    end
  end

  context 'persistent connections' do
    it "detects when the server has closed the connection and reconnects" do
      Puppet[:http_debug] = true

      # advertise that we support keep-alive, but we don't really
      response_proc = -> (req, res) {
        res['Connection'] = 'Keep-Alive'
      }

      https_server.start_server(response_proc: response_proc) do |port|
        uri = URI("https://127.0.0.1:#{port}")
        kwargs = {headers: {'Content-Type' => 'text/plain'}, options: {ssl_context: root_context}}

        expect {
          expect(client.post(uri, '', **kwargs)).to be_success
          # the server closes its connection after each request, so posting
          # again will force ruby to detect that the remote side closed the
          # connection, and reconnect
          expect(client.post(uri, '', **kwargs)).to be_success
        }.to output(/Conn close because of EOF/).to_stderr
      end
    end
  end
end
