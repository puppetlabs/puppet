require 'spec_helper'
require 'puppet/forge'
require 'puppet_spec/https'

describe Puppet::Forge, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  include_context "https client"

  let(:wrong_hostname) { 'localhost' }
  let(:server) { PuppetSpec::HTTPSServer.new }
  let(:ssl_provider) { Puppet::SSL::SSLProvider.new }

  let(:http_response) do
    File.read(fixtures('unit/forge/bacula.json'))
  end

  let(:release_response) do
    releases = JSON.parse(http_response)
    releases['results'] = []
    JSON.dump(releases)
  end

  it 'fetching module release entries' do
    # create a temp cacert bundle
    ssl_file = tmpfile('systemstore')
    File.write(ssl_file, server.ca_cert)

    # override path to system cacert bundle, this must be done before
    # the SSLContext is created and the call to X509::Store.set_default_paths
    Puppet::Util.withenv("SSL_CERT_FILE" => ssl_file) do
      response_proc = -> (req, res) {
        res.status = 200
        res.body = release_response
      }

      server.start_server(response_proc: response_proc) do |port|
        forge = described_class.new("https://127.0.0.1:#{port}")
        forge.fetch('bacula')
      end
    end
  end

  it 'returns a valid exception when there is an SSL verification problem' do
    server.start_server do |port|
      forge = described_class.new("https://#{wrong_hostname}:#{port}")
      expect {
        forge.fetch('mymodule')
      }.to raise_error Puppet::Forge::Errors::SSLVerifyError, %r{^Unable to verify the SSL certificate at https://#{wrong_hostname}}
    end
  end
end
