require 'spec_helper'

require 'puppet/indirector/report/rest'

describe Puppet::Transaction::Report::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    expect(Puppet::Transaction::Report::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  it "should use the :report_server setting in preference to :server" do
    Puppet.settings[:server] = "server"
    Puppet.settings[:report_server] = "report_server"
    expect(Puppet::Transaction::Report::Rest.server).to eq("report_server")
  end

  it "should have a value for report_server and report_port" do
    expect(Puppet::Transaction::Report::Rest.server).not_to be_nil
    expect(Puppet::Transaction::Report::Rest.port).not_to be_nil
  end

  it "should use the :report SRV service" do
    expect(Puppet::Transaction::Report::Rest.srv_service).to eq(:report)
  end

  let(:model) { Puppet::Transaction::Report }
  let(:terminus_class) { Puppet::Transaction::Report::Rest }
  let(:terminus) { model.indirection.terminus(:rest) }
  let(:indirection) { model.indirection }

  before(:each) do
    Puppet::Transaction::Report.indirection.terminus_class = :rest
  end

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = double('http 200 ok', :code => code.to_s, :body => body)
    allow(obj).to receive(:[]).with('content-type').and_return(content_type)
    allow(obj).to receive(:[]).with('content-encoding').and_return(encoding)
    allow(obj).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return(Puppet.version)
    obj
  end

  def save_request(key, instance, options={})
    Puppet::Indirector::Request.new(:report, :find, key, instance, options)
  end

  describe "#save" do
    let(:response) { mock_response(200, 'body') }
    let(:connection) { double('mock http connection', :put => response, :verify_callback= => nil) }
    let(:instance) { model.new('the thing', 'some contents') }
    let(:request) { save_request(instance.name, instance) }
    let(:body) { ["store", "http"].to_pson }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it "deserializes the response as an array of report processor names" do
      response = mock_response('200', body, 'text/pson')
      expect(connection).to receive(:put).and_return(response)

      expect(terminus.save(request)).to eq(["store", "http"])
    end

    describe "when handling the response" do
      describe "when the server major version is less than 5" do
        it "raises if the save fails and we're not using pson" do
          Puppet[:preferred_serialization_format] = "json"

          response = mock_response('500', '{}', 'text/pson')
          allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return("4.10.1")
          expect(connection).to receive(:put).and_return(response)

          expect {
            terminus.save(request)
          }.to raise_error(Puppet::Error, /Server version 4.10.1 does not accept reports in 'json'/)
        end

        it "raises with HTTP 500 if the save fails and we're already using pson" do
          Puppet[:preferred_serialization_format] = "pson"

          response = mock_response('500', '{}', 'text/pson')
          allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return("4.10.1")
          expect(connection).to receive(:put).and_return(response)

          expect {
            terminus.save(request)
          }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
        end
      end
    end
  end
end
