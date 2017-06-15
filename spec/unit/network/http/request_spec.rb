#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet_spec/network'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Request do
  include PuppetSpec::Network

  let(:json_formatter) { Puppet::Network::FormatHandler.format(:json) }
  let(:pson_formatter) { Puppet::Network::FormatHandler.format(:pson) }

  def headers
    {
      'accept' => 'application/json',
      'content-type' => 'application/json'
    }
  end

  def a_request(headers, body = "")
    described_class.from_hash(
      :method => "PUT",
      :path   => "/path/to/endpoint",
      :body   => body,
      :headers => headers
    )
  end

  context "when resolving the formatter for the request body" do
    it "returns the formatter for that Content-Type" do
      request = a_request(headers.merge("content-type" => "application/json"))
      expect(request.formatter).to eq(json_formatter)
    end

    it "raises HTTP 400 if Content-Type is missing" do
      request = a_request({})
      expect {
        request.formatter
      }.to raise_error(bad_request_error, /No Content-Type header was received, it isn't possible to unserialize the request/)
    end

    it "raises HTTP 415 if Content-Type is unsupported" do
      request = a_request(headers.merge('content-type' => 'application/ogg'))
      expect {
        request.formatter
      }.to raise_error(unsupported_media_type_error, /Unsupported Media Type: Client sent a mime-type \(application\/ogg\) that doesn't correspond to a format we support/)
    end

    it "raises HTTP 415 if Content-Type is unsafe yaml" do
      request = a_request(headers.merge('content-type' => 'yaml'))
      expect {
        request.formatter
      }.to raise_error(unsupported_media_type_error, /Unsupported Media Type: Client sent a mime-type \(yaml\) that doesn't correspond to a format we support/)
    end

    it "raises HTTP 415 if Content-Type is unsafe b64_zlib_yaml" do
      request = a_request(headers.merge('content-type' => 'b64_zlib_yaml'))
      expect {
        request.formatter
      }.to raise_error(unsupported_media_type_error, /Unsupported Media Type: Client sent a mime-type \(b64_zlib_yaml\) that doesn't correspond to a format we support/)
    end
  end

  context "when resolving the formatter for the response body" do
    context "when the client doesn't specify an Accept header" do
      it "raises HTTP 400 if the server doesn't specify a default" do
        request = a_request({})
        expect {
          request.response_formatters_for([:json])
        }.to raise_error(bad_request_error, /Missing required Accept header/)
      end

      it "uses the server default" do
        request = a_request({})
        expect(request.response_formatters_for([:json], 'application/json')).to eq([json_formatter])
      end
    end

    it "returns accepted and supported formats, in the accepted order" do
      request = a_request(headers.merge('accept' => 'application/json, application/x-msgpack, text/pson'))
      expect(request.response_formatters_for([:pson, :json])).to eq([json_formatter, pson_formatter])
    end

    it "selects the second format if the first one isn't supported by the server" do
      request = a_request(headers.merge('accept' => 'application/json, text/pson'))
      expect(request.response_formatters_for([:pson])).to eq([pson_formatter])
    end

    it "raises HTTP 406 if Accept doesn't include any server-supported formats" do
      request = a_request(headers.merge('accept' => 'application/ogg'))
      expect {
        request.response_formatters_for([:json])
      }.to raise_error(not_acceptable_error, /No supported formats are acceptable \(Accept: application\/ogg\)/)
    end

    it "raises HTTP 406 if Accept resolves to unsafe yaml" do
      request = a_request(headers.merge('accept' => 'yaml'))
      expect {
        request.response_formatters_for([:json])
      }.to raise_error(not_acceptable_error, /No supported formats are acceptable \(Accept: yaml\)/)
    end

    it "raises HTTP 406 if Accept resolves to unsafe b64_zlib_yaml" do
      request = a_request(headers.merge('accept' => 'b64_zlib_yaml'))
      expect {
        request.response_formatters_for([:json])
      }.to raise_error(not_acceptable_error, /No supported formats are acceptable \(Accept: b64_zlib_yaml\)/)
    end
  end
end
