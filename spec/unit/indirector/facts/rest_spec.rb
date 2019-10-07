require 'spec_helper'

require 'puppet/indirector/facts/rest'

describe Puppet::Node::Facts::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::Node::Facts::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  let(:model) { Puppet::Node::Facts }
  before(:each) { model.indirection.terminus_class = :rest }

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = double('http response', :code => code.to_s, :body => body)
    allow(obj).to receive(:[]).with('content-type').and_return(content_type)
    allow(obj).to receive(:[]).with('content-encoding').and_return(encoding)
    allow(obj).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return(Puppet.version)
    obj
  end

  describe '#save' do
    subject { model.indirection.terminus(:rest) }

    let(:connection) { double('mock http connection', :verify_callback= => nil) }
    let(:node_name) { 'puppet.node.test' }
    let(:data) { model.new(node_name, {test_fact: 'test value'}) }
    let(:request) { Puppet::Indirector::Request.new(:facts, :save, node_name, data) }

    before :each do
      allow(subject).to receive(:network).and_return(connection)
    end

    context 'when a 404 response is received' do
      let(:response) { mock_response(404, '{}', 'test/json') }

      before(:each) { expect(connection).to receive(:put).and_return(response) }

      it 'riases with HTTP 404' do
        expect{ subject.save(request) }.to raise_error(Net::HTTPError,
                                                       /Error 404 on SERVER/)
      end
    end
  end
end
