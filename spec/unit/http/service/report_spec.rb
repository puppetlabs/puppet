require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service::Report do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:subject) { client.create_session.route_to(:report) }
  let(:environment) { 'testing' }
  let(:report) { Puppet::Transaction::Report.new }

  before :each do
    Puppet[:report_server] = 'www.example.com'
    Puppet[:report_port] = 443
  end

  context 'when making requests' do
    let(:uri) {"https://www.example.com:443/puppet/v3/report/report?environment=testing"}

    it 'includes default HTTP headers' do
      stub_request(:put, uri).with do |request|
        expect(request.headers).to include({'X-Puppet-Version' => /./, 'User-Agent' => /./})
        expect(request.headers).to_not include('X-Puppet-Profiling')
      end

      subject.put_report('report', report, environment: environment)
    end
  end

  context 'when routing to the report service' do
    it 'defaults the server and port based on settings' do
      Puppet[:report_server] = 'report.example.com'
      Puppet[:report_port] = 8141

      stub_request(:put, "https://report.example.com:8141/puppet/v3/report/report?environment=testing")

      subject.put_report('report', report, environment: environment)
    end

    it 'fallbacks to server and masterport' do
      Puppet[:report_server] = nil
      Puppet[:report_port] = nil
      Puppet[:server] = 'report2.example.com'
      Puppet[:masterport] = 8142

      stub_request(:put, "https://report2.example.com:8142/puppet/v3/report/report?environment=testing")

      subject.put_report('report', report, environment: environment)
    end
  end

  context 'when submitting a report' do
    let(:url) { "https://www.example.com/puppet/v3/report/infinity?environment=testing" }

    it 'includes puppet headers set via the :http_extra_headers and :profile settings' do
      stub_request(:put, url).with(headers: {'Example-Header' => 'real-thing', 'another' => 'thing', 'X-Puppet-Profiling' => 'true'})

      Puppet[:http_extra_headers] = 'Example-Header:real-thing,another:thing'
      Puppet[:profile] = true

      subject.put_report('infinity', report, environment: environment)
    end

    it 'submits a report to the "report" endpoint' do
      stub_request(:put, url)
        .with(
          headers: {
            'Accept'=>'application/json, application/x-msgpack, text/pson',
            'Content-Type'=>'application/json',
           }).
         to_return(status: 200, body: "", headers: {})

      subject.put_report('infinity', report, environment: environment)
    end

    it 'percent encodes the uri before submitting the report' do
      stub_request(:put, "https://www.example.com/puppet/v3/report/node%20name?environment=testing")
        .to_return(status: 200, body: "", headers: {})

      subject.put_report('node name', report, environment: environment)
    end

    it 'returns the response whose body contains the list of report processors' do
      body = "[\"store\":\"http\"]"
      stub_request(:put, url)
        .to_return(status: 200, body: body, headers: {'Content-Type' => 'application/json'})

      expect(subject.put_report('infinity', report, environment: environment).body).to eq(body)
    end

    it 'raises response error if unsuccessful' do
      stub_request(:put, url).to_return(status: [400, 'Bad Request'], headers: {'X-Puppet-Version' => '6.1.8' })

      expect {
        subject.put_report('infinity', report, environment: environment)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Bad Request')
        expect(err.response.code).to eq(400)
      end
    end

    it 'raises an error if unsuccessful, the server version is < 5, and the current serialization format is not pson' do
      Puppet[:preferred_serialization_format] = 'json'

      stub_request(:put, url).to_return(status: [400, 'Bad Request'], headers: {'X-Puppet-Version' => '4.2.3' })

      expect {
        subject.put_report('infinity', report, environment: environment)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ProtocolError)
        expect(err.message).to eq('To submit reports to a server running puppetserver 4.2.3, set preferred_serialization_format to pson')
      end
    end
  end
end
