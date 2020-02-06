# coding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service::Compiler do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:subject) { client.create_session.route_to(:puppet) }
  let(:environment) { 'testing' }
  let(:certname) { 'ziggy' }
  let(:node) { Puppet::Node.new(certname) }
  let(:facts) { Puppet::Node::Facts.new(certname) }
  let(:catalog) { Puppet::Resource::Catalog.new(certname) }
  let(:status) { Puppet::Status.new }
  let(:formatter) { Puppet::Network::FormatHandler.format(:json) }

  before :each do
    Puppet[:server] = 'compiler.example.com'
    Puppet[:masterport] = 8140

    Puppet::Node::Facts.indirection.terminus_class = :memory
  end

  context 'when making requests' do
    let(:uri) {"https://compiler.example.com:8140/puppet/v3/catalog/ziggy?environment=testing"}

    it 'includes default HTTP headers' do
      stub_request(:post, uri).with do |request|
        expect(request.headers).to include({'X-Puppet-Version' => /./, 'User-Agent' => /./})
        expect(request.headers).to_not include('X-Puppet-Profiling')
      end.to_return(body: formatter.render(catalog), headers: {'Content-Type' => formatter.mime })

      subject.get_catalog(certname, environment: environment, facts: facts)
    end
  end

  context 'when routing to the compiler service' do
    it 'defaults the server and port based on settings' do
      Puppet[:server] = 'compiler2.example.com'
      Puppet[:masterport] = 8141

      stub_request(:post, "https://compiler2.example.com:8141/puppet/v3/catalog/ziggy?environment=testing")
        .to_return(body: formatter.render(catalog), headers: {'Content-Type' => formatter.mime })

      subject.get_catalog(certname, environment: environment, facts: facts)
    end
  end

  context 'when posting for a catalog' do
    let(:uri) { %r{/puppet/v3/catalog/ziggy} }
    let(:catalog_response) { { body: formatter.render(catalog), headers: {'Content-Type' => formatter.mime } } }

    it 'includes puppet headers set via the :http_extra_headers and :profile settings' do
      stub_request(:post, uri).with(headers: {'Example-Header' => 'real-thing', 'another' => 'thing', 'X-Puppet-Profiling' => 'true'}).
        to_return(body: formatter.render(catalog), headers: {'Content-Type' => formatter.mime })

      Puppet[:http_extra_headers] = 'Example-Header:real-thing,another:thing'
      Puppet[:profile] = true

      subject.get_catalog(certname, environment: environment, facts: facts)
    end

    it 'submits facts as application/json by default' do
      stub_request(:post, uri)
        .with(body: hash_including("facts_format" => /application\/json/))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: environment, facts: facts)
    end

    it 'submits facts as pson if set as the preferred format' do
      Puppet[:preferred_serialization_format] = "pson"

      stub_request(:post, uri)
        .with(body: hash_including("facts_format" => /pson/))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: environment, facts: facts)
    end

    it 'includes environment as a query parameter AND in the POST body' do
      stub_request(:post, uri)
        .with(query: {"environment" => "outerspace"},
              body: hash_including("environment" => 'outerspace'))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'outerspace', facts: facts)
    end

    it 'includes configured_environment' do
      stub_request(:post, uri)
        .with(body: hash_including("configured_environment" => 'agent_specified'))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'production', facts: facts, configured_environment: 'agent_specified')
    end

    it 'includes transaction_uuid' do
      uuid = "ec3d2844-b236-4287-b0ad-632fbb4d1ff0"

      stub_request(:post, uri)
        .with(body: hash_including("transaction_uuid" => uuid))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'production', facts: facts, transaction_uuid: uuid)
    end

    it 'includes job_uuid' do
      uuid = "3dd13eec-1b6b-4b5d-867b-148193e0593e"

      stub_request(:post, uri)
        .with(body: hash_including("job_uuid" => uuid))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'production', facts: facts, job_uuid: uuid)
    end

    it 'includes static_catalog' do
      stub_request(:post, uri)
        .with(body: hash_including("static_catalog" => "false"))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'production', facts: facts, static_catalog: false)
    end

    it 'includes dot-separated list of checksum_types' do
      stub_request(:post, uri)
        .with(body: hash_including("checksum_type" => "sha256.sha384"))
        .to_return(**catalog_response)

      subject.get_catalog(certname, environment: 'production', facts: facts, checksum_type: %w[sha256 sha384])
    end

    it 'returns a deserialized catalog' do
      stub_request(:post, uri)
        .to_return(**catalog_response)

      cat = subject.get_catalog(certname, environment: 'production', facts: facts)
      expect(cat).to be_a(Puppet::Resource::Catalog)
      expect(cat.name).to eq(certname)
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:post, uri)
        .to_return(status: [500, "Server Error"])

      expect {
        subject.get_catalog(certname, environment: 'production', facts: facts)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Server Error')
        expect(err.response.code).to eq(500)
      end
    end

    it 'raises a protocol error if the content-type header is missing' do
      stub_request(:post, uri)
        .to_return(body: "content-type is missing")

      expect {
        subject.get_catalog(certname, environment: 'production', facts: facts)
      }.to raise_error(Puppet::HTTP::ProtocolError, /No content type in http response; cannot parse/)
    end

    it 'raises a serialization error if the content is invalid' do
      stub_request(:post, uri)
        .to_return(body: "this isn't valid JSON", headers: {'Content-Type' => 'application/json'})

      expect {
        subject.get_catalog(certname, environment: 'production', facts: facts)
      }.to raise_error(Puppet::HTTP::SerializationError, /Failed to deserialize Puppet::Resource::Catalog from json/)
    end

    context 'serializing facts' do
      facts_with_special_characters = [
        { :hash => { 'afact' => 'a+b' }, :encoded => 'a%2Bb' },
        { :hash => { 'afact' => 'a b' }, :encoded => 'a%20b' },
        { :hash => { 'afact' => 'a&b' }, :encoded => 'a%26b' },
        { :hash => { 'afact' => 'a*b' }, :encoded => 'a%2Ab' },
        { :hash => { 'afact' => 'a=b' }, :encoded => 'a%3Db' },
        # different UTF-8 widths
        # 1-byte A
        # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
        # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
        # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
        { :hash => { 'afact' => "A\u06FF\u16A0\u{2070E}" }, :encoded => 'A%DB%BF%E1%9A%A0%F0%A0%9C%8E' },
      ]

      facts_with_special_characters.each do |test_fact|
        it "escapes special characters #{test_fact[:hash]}" do
          facts = Puppet::Node::Facts.new(certname, test_fact[:hash])
          Puppet::Node::Facts.indirection.save(facts)

          stub_request(:post, uri)
            .with(body: hash_including("facts" => /#{test_fact[:encoded]}/))
            .to_return(**catalog_response)

          subject.get_catalog(certname, environment: environment, facts: facts)
        end
      end
    end
  end

  context 'when getting a node' do
    let(:uri) { %r{/puppet/v3/node/ziggy} }
    let(:node_response) { { body: formatter.render(node), headers: {'Content-Type' => formatter.mime } } }

    it 'includes custom headers set via the :http_extra_headers and :profile settings' do
      stub_request(:get, uri).with(headers: {'Example-Header' => 'real-thing', 'another' => 'thing', 'X-Puppet-Profiling' => 'true'}).
        to_return(**node_response)

      Puppet[:http_extra_headers] = 'Example-Header:real-thing,another:thing'
      Puppet[:profile] = true

      subject.get_node(certname, environment: 'production')
    end

    it 'includes environment' do
      stub_request(:get, uri)
          .with(query: hash_including("environment" => "outerspace"))
          .to_return(**node_response)

      subject.get_node(certname, environment: 'outerspace')
    end

    it 'includes configured_environment' do
      stub_request(:get, uri)
        .with(query: hash_including("configured_environment" => 'agent_specified'))
        .to_return(**node_response)

      subject.get_node(certname, environment: 'production', configured_environment: 'agent_specified')
    end

    it 'includes transaction_uuid' do
      uuid = "ec3d2844-b236-4287-b0ad-632fbb4d1ff0"

      stub_request(:get, uri)
        .with(query: hash_including("transaction_uuid" => uuid))
        .to_return(**node_response)

      subject.get_node(certname, environment: 'production', transaction_uuid: uuid)
    end

    it 'returns a deserialized node' do
      stub_request(:get, uri)
        .to_return(**node_response)

      n = subject.get_node(certname, environment: 'production')
      expect(n).to be_a(Puppet::Node)
      expect(n.name).to eq(certname)
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:get, uri)
        .to_return(status: [500, "Server Error"])

      expect {
        subject.get_node(certname, environment: 'production')
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Server Error')
        expect(err.response.code).to eq(500)
      end
    end

    it 'raises a protocol error if the content-type header is missing' do
      stub_request(:get, uri)
        .to_return(body: "content-type is missing")

      expect {
        subject.get_node(certname, environment: 'production')
      }.to raise_error(Puppet::HTTP::ProtocolError, /No content type in http response; cannot parse/)
    end

    it 'raises a serialization error if the content is invalid' do
      stub_request(:get, uri)
        .to_return(body: "this isn't valid JSON", headers: {'Content-Type' => 'application/json'})

      expect {
        subject.get_node(certname, environment: 'production')
      }.to raise_error(Puppet::HTTP::SerializationError, /Failed to deserialize Puppet::Node from json/)
    end
  end

  context 'when putting facts' do
    let(:uri) { %r{/puppet/v3/facts/ziggy} }

    it 'includes custom headers set the :http_extra_headers and :profile settings' do
      stub_request(:put, uri).with(headers: {'Example-Header' => 'real-thing', 'another' => 'thing', 'X-Puppet-Profiling' => 'true'})

      Puppet[:http_extra_headers] = 'Example-Header:real-thing,another:thing'
      Puppet[:profile] = true

      subject.put_facts(certname, environment: environment, facts: facts)
    end

    it 'serializes facts in the body' do
      facts = Puppet::Node::Facts.new(certname, { 'domain' => 'zork'})
      Puppet::Node::Facts.indirection.save(facts)

      stub_request(:put, uri)
        .with(body: hash_including("name" => "ziggy", "values" => {"domain" => "zork"}))

      subject.put_facts(certname, environment: environment, facts: facts)
    end

    it 'includes environment' do
      stub_request(:put, uri)
        .with(query: {"environment" => "outerspace"})

      subject.put_facts(certname, environment: 'outerspace', facts: facts)
    end

    it 'returns true' do
      # the REST API returns the filename, good grief
      stub_request(:put, uri)
        .to_return(status: 200, body: "/opt/puppetlabs/server/data/puppetserver/yaml/facts/#{certname}.yaml")

      expect(subject.put_facts(certname, environment: environment, facts: facts)).to eq(true)
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:put, uri)
        .to_return(status: [500, "Server Error"])

      expect {
        subject.put_facts(certname, environment: environment, facts: facts)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Server Error')
        expect(err.response.code).to eq(500)
      end
    end

    it 'raises a serialization error if the report cannot be serialized' do
      invalid_facts = Puppet::Node::Facts.new(certname, {'invalid_utf8_sequence' => "\xE2\x82".force_encoding('binary')})
      expect {
        subject.put_facts(certname, environment: 'production', facts: invalid_facts)
      }.to raise_error(Puppet::HTTP::SerializationError, /Failed to serialize Puppet::Node::Facts to json: "\\xE2" from ASCII-8BIT to UTF-8/)
    end
  end

  context 'when getting status' do
    let(:uri) { %r{/puppet/v3/status/ziggy} }
    let(:status_response) { { body: formatter.render(status), headers: {'Content-Type' => formatter.mime } } }

    it 'always sends production' do
      stub_request(:get, uri)
          .with(query: hash_including("environment" => "production"))
          .to_return(**status_response)

      subject.get_status(certname)
    end

    it 'returns a deserialized status' do
      stub_request(:get, uri)
        .to_return(**status_response)

      s = subject.get_status(certname)
      expect(s).to be_a(Puppet::Status)
      expect(s.status).to eq("is_alive" => true)
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:get, uri)
        .to_return(status: [500, "Server Error"])

      expect {
        subject.get_status(certname)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Server Error')
        expect(err.response.code).to eq(500)
      end
    end

    it 'raises a protocol error if the content-type header is missing' do
      stub_request(:get, uri)
        .to_return(body: "content-type is missing")

      expect {
        subject.get_status(certname)
      }.to raise_error(Puppet::HTTP::ProtocolError, /No content type in http response; cannot parse/)
    end

    it 'raises a serialization error if the content is invalid' do
      stub_request(:get, uri)
        .to_return(body: "this isn't valid JSON", headers: {'Content-Type' => 'application/json'})

      expect {
        subject.get_status(certname)
      }.to raise_error(Puppet::HTTP::SerializationError, /Failed to deserialize Puppet::Status from json/)
    end
  end
end
