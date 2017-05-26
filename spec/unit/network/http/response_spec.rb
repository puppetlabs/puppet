#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/handler'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Response do
  include PuppetSpec::Files

  let(:handler) { PuppetSpec::Handler.new }
  let(:response) { {} }
  let(:subject) { described_class.new(handler, response) }
  let(:body_utf8) { JSON.dump({ "foo" => "bar"}).encode('UTF-8') }
  let(:body_shift_jis) { [130, 174].pack('C*').force_encoding(Encoding::Shift_JIS) }
  let(:invalid_shift_jis) { "\xC0\xFF".force_encoding(Encoding::Shift_JIS) }

  context "when passed a response body" do
    it "passes the status code and body to the handler" do
      handler.expects(:set_response).with(response, body_utf8, 200)

      subject.respond_with(200, 'application/json', body_utf8)
    end

    it "accepts a File body" do
      file = tmpfile('response_spec')
      handler.expects(:set_response).with(response, file, 200)

      subject.respond_with(200, 'application/octet-stream', file)
    end
  end

  context "when passed a content type" do
    it "accepts a mime string" do
      handler.expects(:set_content_type).with(response, 'application/json; charset=utf-8')

      subject.respond_with(200, 'application/json', body_utf8)
    end

    it "accepts a format object" do
      formatter = Puppet::Network::FormatHandler.format(:json)
      handler.expects(:set_content_type).with(response, 'application/json; charset=utf-8')

      subject.respond_with(200, formatter, body_utf8)
    end
  end

  context "when resolving charset" do
    context "with binary content" do
      it "omits the charset" do
        body_binary = [0xDEADCAFE].pack('L')

        formatter = Puppet::Network::FormatHandler.format(:binary)
        handler.expects(:set_content_type).with(response, 'application/octet-stream')

        subject.respond_with(200, formatter, body_binary)
      end
    end

    context "with text/plain content" do
      let(:formatter) { Puppet::Network::FormatHandler.format(:s) }

      it "sets the charset to UTF-8 for content already in that format" do
        body_pem = "BEGIN CERTIFICATE".encode('UTF-8')

        handler.expects(:set_content_type).with(response, 'text/plain; charset=utf-8')

        subject.respond_with(200, formatter, body_pem)
      end

      it "encodes the content to UTF-8 for content not already in UTF-8" do
        handler.expects(:set_content_type).with(response, 'text/plain; charset=utf-8')
        handler.expects(:set_response).with(response, body_shift_jis.encode('utf-8'), 200)

        subject.respond_with(200, formatter, body_shift_jis)
      end

      it "raises an exception if transcoding fails" do
        expect {
          subject.respond_with(200, formatter, invalid_shift_jis)
        }.to raise_error(EncodingError, /"\\xFF" on Shift_JIS/)
      end
    end

    context "with application/json content" do
      let(:formatter) { Puppet::Network::FormatHandler.format(:json) }

      it "sets the charset to UTF-8 for content already in that format" do
        handler.expects(:set_content_type).with(response, 'application/json; charset=utf-8')

        subject.respond_with(200, formatter, body_utf8)
      end

      it "encodes the content to UTF-8 for content not already in UTF-8" do
        handler.expects(:set_content_type).with(response, 'application/json; charset=utf-8')
        handler.expects(:set_response).with(response, body_shift_jis.encode('utf-8'), 200)

        subject.respond_with(200, formatter, body_shift_jis)
      end

      it "raises an exception if transcoding fails" do
        expect {
          subject.respond_with(200, formatter, invalid_shift_jis)
        }.to raise_error(EncodingError, /"\\xFF" on Shift_JIS/)
      end
    end
  end
end
