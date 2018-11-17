require 'spec_helper'
require 'puppet_spec/https'
require 'puppet_spec/files'
require 'puppet/rest/client'

describe Puppet::Rest::Client, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  before :all do
    WebMock.disable!
  end

  after :all do
    WebMock.enable!
  end

  let(:hostname) { '127.0.0.1' }
  let(:wrong_hostname) { 'localhost' }
  let(:server) { PuppetSpec::HTTPSServer.new }
  let(:ssl) { Puppet::SSL::SSLProvider.new }
  let(:ssl_context) { ssl.create_root_context(cacerts: [server.ca_cert], crls: [server.ca_crl]) }
  let(:client) { Puppet::Rest::Client.new(ssl_context: ssl_context) }

  before(:each) do
    localcacert = tmpfile('rest_client')
    File.write(localcacert, server.ca_cert.to_pem)
    Puppet[:ssl_client_ca_auth] = localcacert

    # make sure we don't take too long
    Puppet[:http_connect_timeout] = '5s'
  end

  it "connects over SSL" do
    server.start_server do |port|
      uri = URI.parse("https://#{hostname}:#{port}/blah")
      expect { |b|
        client.get(uri, &b)
      }.to yield_with_args('OK')
    end
  end

  it 'provides a meaningful error message when cert validation fails' do
    ssl_context = ssl.create_root_context(
      cacerts: [cert_fixture('netlock-arany-utf8.pem')]
    )
    client = Puppet::Rest::Client.new(ssl_context: ssl_context)

    server.start_server do |port|
      uri = URI.parse("https://#{hostname}:#{port}/blah")
      expect {
        client.get(uri)
      }.to raise_error(Puppet::Error,
                       %r{certificate verify failed.* .self signed certificate in certificate chain for CN=Test CA.})
    end
  end

  it 'provides valuable error message when cert names do not match' do
    server.start_server do |port|
      uri = URI.parse("https://#{wrong_hostname}:#{port}/blah")
      expect {
        client.get(uri)
      }.to raise_error do |error|
        pending("PUP-8213") if RUBY_VERSION.to_f >= 2.4 && !Puppet::Util::Platform.jruby?

        expect(error).to be_instance_of(Puppet::SSL::CertMismatchError)
        expect(error.message).to match(/\AServer hostname '#{wrong_hostname}' did not match server certificate; expected one of (.+)/)

        md = error.message.match(/expected one of (.+)/)
        expect(md[1].split(', ')).to contain_exactly('127.0.0.1', 'DNS:127.0.0.1', 'DNS:127.0.0.2')
      end
    end
  end
end
