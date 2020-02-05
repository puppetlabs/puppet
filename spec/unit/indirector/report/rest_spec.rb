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

  before(:each) do
    described_class.indirection.terminus_class = :rest
  end

  describe "#save" do
    let(:instance) { Puppet::Transaction::Report.new('the thing', 'some contents') }
    let(:body) { ["store", "http"].to_pson }

    it "deserializes the response as an array of report processor names" do
      stub_request(:put, %r{/puppet/v3/report})
        .to_return(status: 200, body: body, headers: { 'Content-Type' => 'text/pson' })

      expect(described_class.indirection.save(instance)).to eq(["store", "http"])
    end

    describe "when handling the response" do
      describe "when the server major version is less than 5" do
        it "raises if the save fails and we're not using pson" do
          Puppet[:preferred_serialization_format] = "json"

          stub_request(:put, %r{/puppet/v3/report})
            .to_return(status: 500,
                       body: "{}",
                       headers: { 'Content-Type' => 'text/pson', Puppet::Network::HTTP::HEADER_PUPPET_VERSION => '4.10.1' })

          expect {
            described_class.indirection.save(instance)
          }.to raise_error(Puppet::Error, /Server version 4.10.1 does not accept reports in 'json'/)
        end

        it "raises with HTTP 500 if the save fails and we're already using pson" do
          Puppet[:preferred_serialization_format] = "pson"

          stub_request(:put, %r{/puppet/v3/report})
            .to_return(status: 500,
                       body: "{}",
                       headers: { 'Content-Type' => 'text/pson', Puppet::Network::HTTP::HEADER_PUPPET_VERSION => '4.10.1' })

          expect {
            described_class.indirection.save(instance)
          }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
        end
      end
    end
  end
end
