require 'spec_helper'

require 'puppet/indirector/node/rest'

describe Puppet::Node::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/node/ziggy} }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }
  let(:node) { Puppet::Node.new(certname) }

  before :each do
    Puppet[:server] = 'compiler.example.com'
    Puppet[:masterport] = 8140

    described_class.indirection.terminus_class = :rest
  end

  def node_response(node)
    { body: formatter.render(node), headers: {'Content-Type' => formatter.mime } }
  end

  it 'finds a node' do
    stub_request(:get, uri).to_return(**node_response(node))

    expect(described_class.indirection.find(certname)).to be_a(Puppet::Node)
  end

  it "serializes the environment" do
    stub_request(:get, uri)
      .with(query: hash_including('environment' => 'outerspace'))
      .to_return(**node_response(node))

    described_class.indirection.find(certname, environment: Puppet::Node::Environment.remote('outerspace'))
  end

  it 'preserves the node environment_name as a symbol' do
    env = Puppet::Node::Environment.remote('outerspace')
    node = Puppet::Node.new(certname, environment: env)

    stub_request(:get, uri).to_return(**node_response(node))

    expect(described_class.indirection.find(certname).environment_name).to eq(:outerspace)
  end

  it 'returns nil if the node does not exist' do
    stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect(described_class.indirection.find(certname)).to be_nil
  end

  it 'raises if fail_on_404 is specified' do
    stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect{
      described_class.indirection.find(certname, fail_on_404: true)
    }.to raise_error(Puppet::Error, %r{Find /puppet/v3/node/ziggy\?environment=\*root\*&fail_on_404=true resulted in 404 with the message: {}})
  end

  it 'raises Net::HTTPError on 500' do
    stub_request(:get, uri).to_return(status: 500)

    expect{
      described_class.indirection.find(certname)
    }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
  end
end
