require 'spec_helper'

require 'puppet/indirector/status/rest'

describe Puppet::Indirector::Status::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/status/ziggy} }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }

  before :each do
    Puppet[:server] = 'compiler.example.com'
    Puppet[:masterport] = 8140

    described_class.indirection.terminus_class = :rest
  end

  def status_response(node)
    { body: formatter.render(node), headers: {'Content-Type' => formatter.mime } }
  end

  it 'finds server status' do
    node = Puppet::Status.new(certname)

    stub_request(:get, uri).to_return(**status_response(node))

    expect(described_class.indirection.find(certname)).to be_a(Puppet::Status)
  end

  it 'returns nil if the node does not exist' do
    stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect(described_class.indirection.find(certname)).to be_nil
  end

  it 'raises if fail_on_404 is specified' do
    stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect{
      described_class.indirection.find(certname, fail_on_404: true)
    }.to raise_error(Puppet::Error, %r{Find /puppet/v3/status/ziggy\?environment=\*root\*&fail_on_404=true resulted in 404 with the message: {}})
  end

  it 'raises Net::HTTPError on 500' do
    stub_request(:get, uri).to_return(status: 500)

    expect{
      described_class.indirection.find(certname)
    }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
  end
end
