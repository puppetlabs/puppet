#! /usr/bin/env ruby
#

require 'spec_helper'
require 'puppet/ssl/configuration'

describe Puppet::SSL::Configuration do
  let(:localcacert) { "/path/to/certs/ca.pem" }

  let(:ssl_server_ca_auth) { "/path/to/certs/ssl_server_ca_auth.pem" }

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎

  it "should require the localcacert argument" do
    expect { subject }.to raise_error ArgumentError
  end

  context "Default configuration" do
    subject do
      described_class.new(localcacert)
    end

    it "#ca_chain_file == localcacert" do
      expect(subject.ca_chain_file).to eq(localcacert)
    end

    it "#ca_auth_file == localcacert" do
      expect(subject.ca_auth_file).to eq(localcacert)
    end
  end

  context "Explicitly configured" do
    subject do
      options = {
        :ca_auth_file  => ssl_server_ca_auth,
      }
      Puppet::SSL::Configuration.new(localcacert, options)
    end

    it "#ca_chain_file == ssl_server_ca_chain" do
      expect(subject.ca_chain_file).to eq(ssl_server_ca_auth)
    end

    it "#ca_auth_file == ssl_server_ca_auth" do
      expect(subject.ca_auth_file).to eq(ssl_server_ca_auth)
    end

    it "#ca_auth_certificates returns an Array<OpenSSL::X509::Certificate>" do
      Puppet::FileSystem.expects(:read).with(subject.ca_auth_file, :encoding => Encoding::UTF_8).returns(utf8_master_intermediate_ca_pem + utf8_root_ca_pem)
      certs = subject.ca_auth_certificates
      certs.each { |cert| expect(cert).to be_a_kind_of OpenSSL::X509::Certificate }
    end
  end

  context "Partially configured" do
    describe "#ca_chain_file" do
      subject do
        described_class.new(localcacert, { :ca_auth_file => ssl_server_ca_auth })
      end

      it "should use ca_auth_file" do
        expect(subject.ca_chain_file).to eq(ssl_server_ca_auth)
      end
    end
  end

  include_context('SSL certificate fixtures')

  def utf8_master_intermediate_ca_pem
    @utf8_master_intermediate_ca_pem ||= "# Master CA #{mixed_utf8}\n#{master_intermediate_ca_pem}"
  end

  def utf8_root_ca_pem
    @utf8_root_ca_pem ||= "# Root CA #{mixed_utf8}\n#{root_ca_pem}"
  end
end
