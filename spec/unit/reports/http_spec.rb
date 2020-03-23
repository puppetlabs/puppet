require 'spec_helper'
require 'puppet/reports'

describe Puppet::Reports.report(:http) do
  subject { Puppet::Transaction::Report.new.extend(described_class) }

  let(:url) { "https://puppet.example.com/report/upload" }

  before :each do
    Puppet[:reporturl] = url
  end

  describe "when setting up the connection" do
    it "raises if the connection fails" do
      stub_request(:post, url).to_raise(Errno::ECONNREFUSED.new('Connection refused - connect(2)'))

      expect {
        subject.process
      }.to raise_error(Puppet::HTTP::HTTPError, /Request to #{url} failed after .* seconds: .*Connection refused/)
    end

    it "configures the connection for ssl when using https" do
      stub_request(:post, url)

      expect_any_instance_of(Net::HTTP).to receive(:start) do |http|
        expect(http).to be_use_ssl
        expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end

      subject.process
    end

    it "does not configure the connection for ssl when using http" do
      Puppet[:reporturl] = 'http://puppet.example.com:8080/the/path'
      stub_request(:post, Puppet[:reporturl])

      expect_any_instance_of(Net::HTTP).to receive(:start) do |http|
        expect(http).to_not be_use_ssl
      end

      subject.process
    end
  end

  describe "when making a request" do
    it "uses the path specified by the 'reporturl' setting" do
      req = stub_request(:post, url)

      subject.process

      expect(req).to have_been_requested
    end

    it "uses the username and password specified by the 'reporturl' setting" do
      Puppet[:reporturl] = "https://user:pass@puppet.example.com/report/upload"

      req = stub_request(:post, %r{/report/upload}).with(basic_auth: ['user', 'pass'])

      subject.process

      expect(req).to have_been_requested
    end

    it "passes metric_id options" do
      stub_request(:post, url)

      expect(Puppet.runtime['http']).to receive(:post).with(anything, hash_including(options: hash_including(metric_id: [:puppet, :report, :http]))).and_call_original

      subject.process
    end

    it "passes the report as YAML" do
      req = stub_request(:post, url).with(body: subject.to_yaml)

      subject.process

      expect(req).to have_been_requested
    end

    it "sets content-type to 'application/x-yaml'" do
      req = stub_request(:post, url).with(headers: {'Content-Type' => 'application/x-yaml'})

      subject.process

      expect(req).to have_been_requested
    end

    it "doesn't log anything if the request succeeds" do
      req = stub_request(:post, url).to_return(status: [200, "OK"])

      subject.process

      expect(req).to have_been_requested
      expect(@logs).to eq([])
    end

    it "follows redirects" do
      location = {headers: {'Location' => url}}

      req = stub_request(:post, url)
              .to_return(**location, status: [301, "Moved Permanently"]).then
              .to_return(**location, status: [302, "Found"]).then
              .to_return(**location, status: [307, "Temporary Redirect"]).then
              .to_return(status: [200, "OK"])

      subject.process

      expect(req).to have_been_requested.times(4)
    end

    it "logs an error if the request fails" do
      stub_request(:post, url).to_return(status: [500, "Internal Server Error"])

      subject.process

      expect(@logs).to include(having_attributes(level: :err, message: "Unable to submit report to #{url} [500] Internal Server Error"))
    end
  end
end
