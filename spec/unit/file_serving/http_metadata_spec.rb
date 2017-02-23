#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_serving/http_metadata'
require 'matchers/json'
require 'net/http'
require 'digest'

describe Puppet::FileServing::HttpMetadata do
  let(:foobar) { File.expand_path('/foo/bar') }

  it "should be a subclass of Metadata" do
    expect( described_class.superclass ).to be Puppet::FileServing::Metadata
  end

  describe "when initializing" do
    let(:http_response) { Net::HTTPOK.new(1.0, '200', 'OK') }

    it "can be instantiated from a HTTP response object" do
      expect( described_class.new(http_response) ).to_not be_nil
    end

    it "represents a plain file" do
      expect( described_class.new(http_response).ftype ).to eq 'file'
    end

    it "carries no information on owner, group and mode" do
      metadata = described_class.new(http_response)
      expect( metadata.owner ).to be_nil
      expect( metadata.group ).to be_nil
      expect( metadata.mode ).to be_nil
    end

    context "with no Last-Modified or Content-MD5 header from the server" do
      before do
        http_response.stubs(:[]).with('last-modified').returns nil
        http_response.stubs(:[]).with('content-md5').returns nil
      end

      it "should use :mtime as the checksum type, based on current time" do
        # Stringifying Time.now does some rounding; do so here so we don't end up with a time
        # that's greater than the stringified version returned by collect.
        time = Time.parse(Time.now.to_s)
        metadata = described_class.new(http_response)
        metadata.collect
        expect( metadata.checksum_type ).to eq :mtime
        checksum = metadata.checksum
        expect( checksum[0...7] ).to eq '{mtime}'
        expect( Time.parse(checksum[7..-1]) ).to be >= time
      end
    end

    context "with a Last-Modified header from the server" do
      let(:time) { Time.now.utc }
      before do
        http_response.stubs(:[]).with('content-md5').returns nil
      end

      it "should use :mtime as the checksum type, based on Last-Modified" do
        # HTTP uses "GMT" not "UTC"
        http_response.stubs(:[]).with('last-modified').returns(time.strftime("%a, %d %b %Y %T GMT"))
        metadata = described_class.new(http_response)
        metadata.collect
        expect( metadata.checksum_type ).to eq :mtime
        expect( metadata.checksum ).to eq "{mtime}#{time.to_time.utc}"
      end
    end

    context "with a Content-MD5 header being received" do
      let(:input) { Time.now.to_s }
      let(:base64) { Digest::MD5.new.base64digest input }
      let(:hex) { Digest::MD5.new.hexdigest input }
      before do
        http_response.stubs(:[]).with('last-modified').returns nil
        http_response.stubs(:[]).with('content-md5').returns base64
      end

      it "should use the md5 checksum" do
        metadata = described_class.new(http_response)
        metadata.collect
        expect( metadata.checksum_type ).to eq :md5
        expect( metadata.checksum ).to eq "{md5}#{hex}"
      end
    end
  end
end
