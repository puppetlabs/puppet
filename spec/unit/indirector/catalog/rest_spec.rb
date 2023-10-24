require 'spec_helper'

require 'puppet/indirector/catalog/rest'

describe Puppet::Resource::Catalog::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/catalog/ziggy} }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }
  let(:catalog) { Puppet::Resource::Catalog.new(certname) }

  before :each do
    Puppet[:server] = 'compiler.example.com'
    Puppet[:serverport] = 8140

    described_class.indirection.terminus_class = :rest
  end

  def catalog_response(catalog)
    { body: formatter.render(catalog), headers: {'Content-Type' => formatter.mime } }
  end

  it 'finds a catalog' do
    stub_request(:post, uri).to_return(**catalog_response(catalog))

    expect(described_class.indirection.find(certname)).to be_a(Puppet::Resource::Catalog)
  end

  it 'logs a notice when requesting a catalog' do
    expect(Puppet).to receive(:notice).with("Requesting catalog from compiler.example.com:8140")

    stub_request(:post, uri).to_return(**catalog_response(catalog))

    described_class.indirection.find(certname)
  end

  it 'logs a notice when the IP address is resolvable when requesting a catalog' do
    allow(Resolv).to receive_message_chain(:getaddress).and_return('192.0.2.0')
    expect(Puppet).to receive(:notice).with("Requesting catalog from compiler.example.com:8140 (192.0.2.0)")

    stub_request(:post, uri).to_return(**catalog_response(catalog))

    described_class.indirection.find(certname)
  end

  it "serializes the environment" do
    stub_request(:post, uri)
      .with(query: hash_including('environment' => 'outerspace'))
      .to_return(**catalog_response(catalog))

    described_class.indirection.find(certname, environment: Puppet::Node::Environment.remote('outerspace'))
  end

  it "passes 'check_environment'" do
    stub_request(:post, uri)
      .with(body: hash_including('check_environment' => 'true'))
      .to_return(**catalog_response(catalog))

    described_class.indirection.find(certname, check_environment: true)
  end

  it 'constructs a catalog environment_instance' do
    env = Puppet::Node::Environment.remote('outerspace')
    catalog = Puppet::Resource::Catalog.new(certname, env)

    stub_request(:post, uri).to_return(**catalog_response(catalog))

    expect(described_class.indirection.find(certname).environment_instance).to eq(env)
  end

  it 'returns nil if the node does not exist' do
    stub_request(:post, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect(described_class.indirection.find(certname)).to be_nil
  end

  it 'raises if fail_on_404 is specified' do
    stub_request(:post, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect{
      described_class.indirection.find(certname, fail_on_404: true)
    }.to raise_error(Puppet::Error, %r{Find /puppet/v3/catalog/ziggy resulted in 404 with the message: {}})
  end

  it 'raises Net::HTTPError on 500' do
    stub_request(:post, uri).to_return(status: 500)

    expect{
      described_class.indirection.find(certname)
    }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
  end
end
