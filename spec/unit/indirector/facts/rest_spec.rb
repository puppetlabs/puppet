require 'spec_helper'

require 'puppet/indirector/facts/rest'

describe Puppet::Node::Facts::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/facts/ziggy} }
  let(:facts) { Puppet::Node::Facts.new(certname, test_fact: 'test value') }

  before do
    Puppet[:server] = 'compiler.example.com'
    Puppet[:masterport] = 8140

    described_class.indirection.terminus_class = :rest
  end

  describe '#find' do
    let(:formatter) { Puppet::Network::FormatHandler.format(:json) }

    def facts_response(facts)
      { body: formatter.render(facts), headers: {'Content-Type' => formatter.mime } }
    end

    it 'finds facts' do
      facts = Puppet::Node::Facts.new(certname)

      stub_request(:get, uri).to_return(**facts_response(facts))

      expect(described_class.indirection.find(certname)).to be_a(Puppet::Node::Facts)
    end

    it 'returns nil if the facts do not exist' do
      stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

      expect(described_class.indirection.find(certname)).to be_nil
    end

    it 'raises if fail_on_404 is specified' do
      stub_request(:get, uri).to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

      expect{
        described_class.indirection.find(certname, fail_on_404: true)
      }.to raise_error(Puppet::Error, %r{Find /puppet/v3/facts/ziggy\?environment=\*root\*&fail_on_404=true resulted in 404 with the message: {}})
    end

    it 'raises Net::HTTPError on 500' do
      stub_request(:get, uri).to_return(status: 500)

      expect{
        described_class.indirection.find(certname)
      }.to raise_error(Net::HTTPError, %r{Error 500 on SERVER: })
    end
  end

  describe '#save' do
    it 'returns nil on success' do
      stub_request(:put, %r{/puppet/v3/facts})
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json'}, body: '')

      expect(described_class.indirection.save(facts)).to be_nil
    end

    it 'raises if options are specified' do
      expect {
        described_class.indirection.save(facts, nil, foo: :bar)
      }.to raise_error(ArgumentError, /PUT does not accept options/)
    end

    it 'raises with HTTP 404' do
      stub_request(:put, %r{/puppet/v3/facts}).to_return(status: 404)

      expect {
        described_class.indirection.save(facts)
      }.to raise_error(Net::HTTPError, /Error 404 on SERVER/)
    end

    it 'raises with HTTP 500' do
      stub_request(:put, %r{/puppet/v3/facts}).to_return(status: 500)

      expect {
        described_class.indirection.save(facts)
      }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
    end
  end
end
