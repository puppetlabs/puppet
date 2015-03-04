#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/digest'

describe Puppet::SSL::Digest do
  it "defaults to sha256" do
    digest = described_class.new(nil, 'blah')
    expect(digest.name).to eq('SHA256')
    expect(digest.digest.hexdigest).to eq("8b7df143d91c716ecfa5fc1730022f6b421b05cedee8fd52b1fc65a96030ad52")
  end

  describe '#name' do
    it "prints the hashing algorithm used by the openssl digest" do
      expect(described_class.new('SHA224', 'blah').name).to eq('SHA224')
    end

    it "upcases the hashing algorithm" do
      expect(described_class.new('sha224', 'blah').name).to eq('SHA224')
    end
  end

  describe '#to_hex' do
    it "returns ':' separated upper case hex pairs" do
      described_class.new(nil, 'blah').to_hex =~ /\A([A-Z0-9]:)+[A-Z0-9]\Z/
    end
  end

  describe '#to_s' do
    it "formats the digest algorithm and the digest as a string" do
      digest = described_class.new('sha512', 'some content')
      expect(digest.to_s).to eq("(#{digest.name}) #{digest.to_hex}")
    end
  end
end
