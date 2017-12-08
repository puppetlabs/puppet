#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/facts/rest'

describe Puppet::Node::Facts::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::Node::Facts::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  let(:model) { Puppet::Node::Facts }
  before(:each) { model.indirection.terminus_class = :rest }

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = stub('http response', :code => code.to_s, :body => body)
    obj.stubs(:[]).with('content-type').returns(content_type)
    obj.stubs(:[]).with('content-encoding').returns(encoding)
    obj.stubs(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).returns(Puppet.version)
    obj
  end

  describe '#save' do
    subject { model.indirection.terminus(:rest) }

    let(:connection) { stub('mock http connection', :verify_callback= => nil) }
    let(:node_name) { 'puppet.node.test' }
    let(:data) { model.new(node_name, {test_fact: 'test value'}) }
    let(:request) { Puppet::Indirector::Request.new(:facts, :save, node_name, data) }

    before :each do
      subject.stubs(:network).returns(connection)
    end

    context 'when a 404 response is received' do
      let(:response) { mock_response(404, '{}', 'test/json') }

      before(:each) { connection.expects(:put).returns response }

      it 'riases with HTTP 404' do
        expect{ subject.save(request) }.to raise_error(Net::HTTPError,
                                                       /Error 404 on SERVER/)
      end
    end
  end
end
