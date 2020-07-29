require 'spec_helper'

require 'puppet/indirector/report/rest'

describe Puppet::Transaction::Report::Rest do
  let(:certname) { 'ziggy' }
  let(:uri) { %r{/puppet/v3/report/ziggy} }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }
  let(:report) do
    report = Puppet::Transaction::Report.new
    report.host = certname
    report
  end

  before(:each) do
    described_class.indirection.terminus_class = :rest
  end

  def report_response
    { body: formatter.render(["store", "http"]), headers: {'Content-Type' => formatter.mime } }
  end

  it "saves a report " do
    stub_request(:put, uri)
      .to_return(status: 200, **report_response)

    described_class.indirection.save(report)
  end

  it "serializes the environment" do
    stub_request(:put, uri)
      .with(query: hash_including('environment' => 'outerspace'))
      .to_return(**report_response)

    described_class.indirection.save(report, nil, environment: Puppet::Node::Environment.remote('outerspace'))
  end

  it "deserializes the response as an array of report processor names" do
    stub_request(:put, %r{/puppet/v3/report})
      .to_return(status: 200, **report_response)

    expect(described_class.indirection.save(report)).to eq(["store", "http"])
  end

  it "returns nil if the node does not exist" do
    stub_request(:put, uri)
      .to_return(status: 404, headers: { 'Content-Type' => 'application/json' }, body: "{}")

    expect(described_class.indirection.save(report)).to be_nil
  end

  it "parses charset from response content-type" do
    stub_request(:put, uri)
      .to_return(status: 200, body: JSON.dump(["store"]), headers: { 'Content-Type' => 'application/json;charset=utf-8' })

    expect(described_class.indirection.save(report)).to eq(["store"])
  end

  describe "when the server major version is less than 5" do
    it "raises if the save fails and we're not using pson" do
      Puppet[:preferred_serialization_format] = "json"

      stub_request(:put, uri)
        .to_return(status: 500,
                   headers: { 'Content-Type' => 'text/pson', Puppet::Network::HTTP::HEADER_PUPPET_VERSION => '4.10.1' })

      expect {
        described_class.indirection.save(report)
      }.to raise_error(Puppet::Error, /To submit reports to a server running puppetserver 4.10.1, set preferred_serialization_format to pson/)
    end

    it "raises with HTTP 500 if the save fails and we're already using pson" do
      Puppet[:preferred_serialization_format] = "pson"

      stub_request(:put, uri)
        .to_return(status: 500,
                   headers: { 'Content-Type' => 'text/pson', Puppet::Network::HTTP::HEADER_PUPPET_VERSION => '4.10.1' })

      expect {
        described_class.indirection.save(report)
      }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
    end
  end
end
